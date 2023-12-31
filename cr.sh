#!/usr/bin/env bash

# Copyright The Helm Authors & Outworld
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

DEFAULT_CHART_RELEASER_VERSION=v1.6.1

main() {
  local version="${PLUGIN_VERSION:-$DEFAULT_CHART_RELEASER_VERSION}"
  local config="$PLUGIN_CONFIG"
  local charts_dir="${PLUGIN_CHARTS_DIR:-charts}"
  local owner="${PLUGIN_OWNER:-$DRONE_REPO_OWNER}"
  local repo="${PLUGIN_REPO:-$DRONE_REPO_NAME}"
  local install_dir="${PLUGIN_INSTALL_DIR:-/var/tmp}"
  local install_only=$PLUGIN_INSTALL_ONLY
  local skip_packaging=$PLUGIN_SKIP_PACKAGING
  local skip_existing=$PLUGIN_SKIP_EXISTING
  local skip_upload=$PLUGIN_SKIP_UPLOAD
  local mark_as_latest="${PLUGIN_MARK_AS_LATEST:-true}"
  local packages_with_index=${PLUGIN_PACKAGES_WITH_INDEX:-false}
  local pages_branch="$PLUGIN_PAGES_BRANCH"
  local cr_token="$PLUGIN_CR_TOKEN"
  local root_package=$PLUGIN_ROOT_PACKAGE

  check_if_install_only

  local repo_root
  repo_root=$(git rev-parse --show-toplevel)
  pushd "$repo_root" >/dev/null

  : "${cr_token:?ERROR: settings.cr_token  must be set}"

  if [[ -z "$skip_packaging" ]]; then
    if [[ -n "$root_package" ]]; then

      echo "Looking for Chart.yaml in root repository"

      local changed_charts=()

      local chart_file="Chart.yaml"

      ls

      if [[ -f "$chart_file" ]]; then
        echo "Chart.yaml found in root repository"
        install_chart_releaser
        rm -rf .cr-release-packages
        mkdir -p .cr-release-packages

        rm -rf .cr-index
        mkdir -p .cr-index

        package_chart "."

        release_charts
        update_index
        echo "changed_charts=$(
          IFS=,
          echo "${chart_file}"
        )" >changed_charts.txt
      else
        echo "No Chart.yaml detected in root repository"
        echo "changed_charts=" >changed_charts.txt
      fi
    else
      echo 'Looking up latest tag...'
      local latest_tag
      latest_tag=$(lookup_latest_tag)

      echo "Discovering changed charts since '$latest_tag'..."
      local changed_charts=()
      readarray -t changed_charts <<<"$(lookup_changed_charts "$latest_tag")"

      if [[ -n "${changed_charts[*]}" ]]; then
        install_chart_releaser

        rm -rf .cr-release-packages
        mkdir -p .cr-release-packages

        rm -rf .cr-index
        mkdir -p .cr-index

        for chart in "${changed_charts[@]}"; do
          if [[ -d "$chart" ]]; then
            package_chart "$chart"
          else
            echo "Nothing to do. No chart changes detected."
          fi
        done

        release_charts
        update_index
        echo "changed_charts=$(
          IFS=,
          echo "${changed_charts[*]}"
        )" >changed_charts.txt
      else
        echo "Nothing to do. No chart changes detected."
        echo "changed_charts=" >changed_charts.txt
      fi
    fi
  else
    install_chart_releaser
    rm -rf .cr-index
    mkdir -p .cr-index
    release_charts
    update_index
  fi

  echo "chart_version=${latest_tag}" >chart_version.txt

  popd >/dev/null
}

check_if_install_only() {
  if [[ -n "$install_only" ]]; then
    echo "Will install cr tool and not run it..."
    install_chart_releaser
    exit 0
  fi
}

install_chart_releaser() {
  if [[ ! -d "$install_dir" ]]; then
    echo "Creating directory $install_dir..."
    mkdir -p "$install_dir"
  fi

  echo "Installing chart-releaser on $install_dir..."
  curl -sSLo cr.tar.gz "https://github.com/helm/chart-releaser/releases/download/$version/chart-releaser_${version#v}_linux_amd64.tar.gz"
  tar -xzf cr.tar.gz -C "$install_dir"
  rm -f cr.tar.gz

  echo 'Adding cr directory to PATH...'
  export PATH="$install_dir:$PATH"
}

lookup_latest_tag() {
  git fetch --tags >/dev/null 2>&1

  if ! git describe --tags --abbrev=0 HEAD~ 2>/dev/null; then
    git rev-list --max-parents=0 --first-parent HEAD
  fi
}

filter_charts() {
  while read -r chart; do
    [[ ! -d "$chart" ]] && continue
    local file="$chart/Chart.yaml"
    if [[ -f "$file" ]]; then
      echo "$chart"
    else
      echo "WARNING: $file is missing, assuming that '$chart' is not a Helm chart. Skipping." 1>&2
    fi
  done
}

lookup_changed_charts() {
  local commit="$1"

  local changed_files
  changed_files=$(git diff --find-renames --name-only "$commit" -- "$charts_dir")

  local depth=$(($(tr "/" "\n" <<<"$charts_dir" | sed '/^\(\.\)*$/d' | wc -l) + 1))
  local fields="1-${depth}"

  cut -d '/' -f "$fields" <<<"$changed_files" | uniq | filter_charts
}

package_chart() {

  local chart="$1"

  local args=("$chart" --package-path .cr-release-packages)
  if [[ -n "$config" ]]; then
    args+=(--config "$config")
  fi

  echo "Packaging chart '$chart'..."
  cr package "${args[@]}"
}

release_charts() {
  local args=(-o "$owner" -r "$repo" -c "$(git rev-parse HEAD)")
  if [[ -n "$config" ]]; then
    args+=(--config "$config")
  else
    args+=(-t "$cr_token")
  fi
  if [[ "$packages_with_index" = true ]]; then
    args+=(--packages-with-index --push --skip-existing)
  elif [[ -n "$skip_existing" ]]; then
    args+=(--skip-existing)
  fi
  if [[ "$mark_as_latest" = false ]]; then
    args+=(--make-release-latest=false)
  fi
  if [[ -n "$pages_branch" ]]; then
    args+=(--pages-branch "$pages_branch")
  fi

  echo 'Releasing charts...'
  cr upload "${args[@]}"
}

update_index() {
  if [[ -n "$skip_upload" ]]; then
    echo "Skipping index upload..."
    return
  fi

  local args=(-o "$owner" -r "$repo" --push)
  if [[ -n "$config" ]]; then
    args+=(--config "$config")
  else
    args+=(-t "$cr_token")
  fi
  if [[ "$packages_with_index" = true ]]; then
    args+=(--packages-with-index --index-path .)
  fi
  if [[ -n "$pages_branch" ]]; then
    args+=(--pages-branch "$pages_branch")
  fi

  echo 'Updating charts repo index...'
  cr index "${args[@]}"
}

main "$@"
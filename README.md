# drone-chart-releaser-github-pages
![GitHub License](https://img.shields.io/github/license/otwld/drone-chart-releaser-github-pages)
[![Build Status](https://drone.outworld.fr/api/badges/otwld/drone-chart-releaser-github-pages/status.svg)](https://drone.outworld.fr/otwld/drone-chart-releaser-github-pages)
![Docker Image Version (latest semver)](https://img.shields.io/docker/v/otwld/drone-chart-releaser-github-pages?label=docker%20image)
![Docker Image Size (tag)](https://img.shields.io/docker/image-size/otwld/drone-chart-releaser-github-pages/latest)


A Drone Plugin to turn a GitHub project into a self-hosted Helm chart repo, using [helm/chart-releaser](https://github.com/helm/chart-releaser) CLI tool.

This plugin is based and inspired by the [chart-releaser-action](https://github.com/helm/chart-releaser-action).

## Usage

### Pipeline Overview
```yaml
kind: pipeline
name: default

steps:
- name: publish
  image: otwld/drone-chart-releaser-github-pages
  settings:
    cr_token:
      from_secret: github_access_token
    skip_existing: true
```
### Pre-requisites

1. One of these confuguration
    - A GitHub repo containing a single chart in root directory (Chart.yaml) 
    - A directory with your Helm charts (default is a folder named `/charts`, if you want to
       maintain your charts in a different directory, you must include a `settings.charts_dir` input in the plugin settings).
2. GitHub branch called `gh-pages` to store the published charts.
3. In your repo, go to Settings/Pages. Change the `Source` `Branch` to `gh-pages`.
4. Create a `.drone.yml` file in your root directory. [Pipelines examples](#example-pipeline) are available below.
   For more information, reference the Drone CI Help Documentation for [Pipeline Overview](https://docs.drone.io/pipeline/overview/)

### Inputs

| Setting properties | type   | default           | required                                                 | description                                                                                                                                                                                                                   |
|--------------------|--------|-------------------|----------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `version`          | string | `v1.6.1`          | optional                                                 | The chart-releaser version to use                                                                                                                                                                                             |
| `config`           | string | ` `               | optional                                                 | Config file for chart-releaser. For more information on the config file, see the [documentation](https://github.com/helm/chart-releaser#config-file)                                                                          |  
| `chart_dir`        | string | `charts`          | **required** in case of **non root single chart** repository | The charts directory                                                                                                                                                                                                          |
| `owner` | string | $DRONE_REPO_OWNER | optional                                                 | The owner's name repository used for chart-releaser                                                                                                                                                                           |                                                                                                        |
| `repo`  | string | $DRONE_REPO_NAME  | optional                                                 | The repository name used for chart-releaser                                                                                                                                                                                   |   
| `skip_packaging` | boolean | false             | optional                                                 | Skip the packaging step. This allows you to do more advanced packaging of your charts (for example, with the `helm package` command) before this action runs. This action will only handle the indexing and publishing steps. 
| `skip_existing` | boolean | false             | optional                                                 | Skip package upload if release/tag already exists                                                                                                                                                                             |
| `skip_upload` | boolean | false             | optional                                                 | Skip the upload step. This allows you to do more advanced uploading of your charts (for exemple with OCI based repositories) which doen't require the `index.yaml`.                                                           |
| `mark_as_latest` | boolean | true              | optional                                                 | When you set this to `false`, it will mark the created GitHub release not as 'latest'.                                                                                                                                        |
| `packages_with_index` | boolean | false             | optional                                                 | When you set this to `true`, it will upload chart packages directly into publishing branch.                                                                                                                                   |
| `pages_branch` | string | `gh-pages`        | optional                                                 | Name of the branch to be used to push the index and artifacts. (default to: gh-pages but it is not set in the action it is a default value for the chart-releaser binary)                                                     |
| `cr_token` | string | ` `               | **required**                                             | The GitHub token of this repository                                                                                                                                                                                           |
| `root_package` | boolean | false             | **required**   in case of **root single chart** repository                                         | In case single chart chart in root repository, set it to true                                                                                                                                                                 |
| `install_only` | boolean | false             | _used for CI_                                            | This is used for the CI.                                                                                                                                                                                                      |
| `install_dir` | string | `/var/tmp`        | _used for CI_                                            | This is used for the CI.   


### Outputs

- `changed_charts.txt`: A comma-separated list of charts that were released on this run. Will be an empty string if no updates were detected, will be unset if `settings.skip_packaging` is used: in the latter case your custom packaging step is responsible for setting its own outputs if you need them.
- `chart_version.txt`: The version of the most recently generated charts; will be set even if no charts have been updated since the last run.


### Pipelines examples

### Example for multicharts repository
```yaml
kind: pipeline
name: default

steps:
- name: publish
  image: otwld/drone-chart-releaser-github-pages
  settings:
    cr_token:
      from_secret: github_access_token
    skip_existing: true
    charts_dir: 'charts'  # Specify the charts directory
```
### Example for single chart repository
```yaml
kind: pipeline
name: default

steps:
- name: publish
  image: otwld/drone-chart-releaser-github-pages
  settings:
    cr_token:
      from_secret: github_access_token
    skip_existing: true 
    root_package: true # Specify single chart repository
```

For options see [config-file](https://github.com/helm/chart-releaser#config-file).


## Support

- For questions, suggestions, and discussion about the Helm Chart Releaser please refer to the [Chart Releaser issue page](https://github.com/helm/chart-releaser/issues)
- For questions, suggestions, and discussion about this plugin please visite [Drone Chart Releaser Github issue page](https://github.com/otwld/drone-chart-releaser-github-pages/issues)
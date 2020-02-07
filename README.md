# action-ebuild-keyword

Automatically update the KEYWORD variable for an ebuild based on the keywords of all dependencies.

## Functionality

Once configured a schedule will trigger the workflow and automatically:
  * update each ebuild to use the best possible `KEYWORDS`
  * regenerate manifest files
  * perform QA tests using [repoman](https://wiki.gentoo.org/wiki/Repoman)
  * deploy to an overlay repository
  * create / update a pull request

## Basic Use

### 1. Configure `action-ebuild-release` for this project.

Before this action can be used [action-ebuild-release](https://github.com/hacking-gentoo/action-ebuild-release) needs to be configured for the project.

### 2. Create a GitHub workflow file

`.github/workflows/action-ebuild-keyword.yml`

```yaml
name: Ebuild Keyword

on:
  repository_dispatch:
  schedule:
    - cron: "0 6 * * 1"

jobs:
  action-ebuild-keyword:
    runs-on: ubuntu-latest
    steps:
    # Check out the repository
    - uses: actions/checkout@master

    # Prepare the environment
    - name: Prepare
      id: prepare
      run: |
        echo "::set-output name=datetime::$(date +"%Y%m%d%H%M")"
        echo "::set-output name=workspace::${GITHUB_WORKSPACE}"
        mkdir -p "${GITHUB_WORKSPACE}/distfiles" "${GITHUB_WORKSPACE}/binpkgs"

    # Cache distfiles and binary packages
    - name: Cache distfiles
      id: cache-distfiles
      uses: gerbal/always-cache@v1.0.3
      with:
        path: ${{ steps.prepare.outputs.workspace }}/distfiles
        key: distfiles-${{ steps.prepare.outputs.datetime }}
        restore-keys: |
          distfiles-${{ steps.prepare.outputs.datetime }}
          distfiles

    # Run the ebuild keyword action
    - uses: hacking-gentoo/action-ebuild-keyword@next
      with:
        auth_token: ${{ secrets.PR_TOKEN }}
        deploy_key: ${{ secrets.DEPLOY_KEY }}
        overlay_repo: hacking-actions/overlay-playground    
```

### 3. Create tokens / keys for automatic deployment

#### Configuring `PR_TOKEN`

The above workflow requires a [personal access token](https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line) be configured for the user running the release action.

This access token will need to be made available to the workflow using the [secrets](https://help.github.com/en/github/automating-your-workflow-with-github-actions/virtual-environments-for-github-actions#creating-and-using-secrets-encrypted-variables)
feature and will be used to authenticate when creating a new pull request.

#### Configuring `DEPLOY_KEY`

The above workflow also requires a [deploy key](https://developer.github.com/v3/guides/managing-deploy-keys/#deploy-keys)
be configured for the destination repository.

This deploy key will also need to be made available to the workflow using the [secrets](https://help.github.com/en/github/automating-your-workflow-with-github-actions/virtual-environments-for-github-actions#creating-and-using-secrets-encrypted-variables)
feature.

### 4. (Optionally) Manually trigger the action 

The action can be manually triggered using a `repository dispatch event`.

```bash
curl -H "Accept: application/vnd.github.everest-preview+json" \
  -H "Authorization: token YOUR_PR_TOKEN" \
  --request POST \
  --data '{"event_type": "do-something"}' \
  https://api.github.com/repos/USER/REPOSITORY/dispatches
```

NOTE: You will need to replace `YOUR_PR_TOKEN` in the above example with your own `PR_TOKEN` (as configured earlier) and replace the `USER` and `REPOSITORY` values with the appropriate user and repository.

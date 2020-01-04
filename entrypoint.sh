#!/bin/bash

cd "${GITHUB_WORKSPACE}" \
  || (echo "Workspace is unavailable" >&2; exit 1)

set -eu

if [ ! -d root ]
then
  echo "Must have ./root directory" >&2
  exit 1
fi

version=$(basename ${GITHUB_REF})

echo -e "machine github.com\nlogin ${INPUT_GITHUB_TOKEN}" > ~/.netrc
git config --global user.name ${INPUT_GIT_USER}
git config --global user.email ${INPUT_GIT_EMAIL}

for repo in ${INPUT_REPOS}
do
  echo "Syncing ${repo}"
  tmpdir=$(mktemp -d)
  git clone -C ${tmpdir} --depth=1 https://github.com/${repo}
  git checkout -C ${tmpdir} -b sync-assets-${version}

  # Copy files with directory structure
  for file in $(cd root; find .)
  do
    echo "- Copying ${file}"
    cp ${file} ${tmpdir}/${file}
  done

  if ! git -C ${tmpdir} diff --exit-code
  then
    echo "- ${repo} is up-to-date"
    rm -rf ${tmpdir}
    continue
  fi

  git -C ${tmpdir} add .
  git -C ${tmpdir} commit -m "Update assets to ${version}"
  git -C ${tmpdir} push origin sync-assets-${version}
  base_branch=$(git -C ${tmpdir} symbolic-ref --short HEAD)

  # Open PR
  echo "- Opening PR"
  (cd ${tmpdir}; hub pull-request \
    -b ${base_branch} \
    -h sync-assets-${version} \
    --no-edit \
    "Update assets to ${version}")

  rm -rf ${tmpdir}
done
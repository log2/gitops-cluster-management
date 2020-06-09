#!/usr/bin/env bash

source /hooks/common/functions.sh

hook::config() {
  cat <<EOF
{
  "configVersion":"v1",
  "kubernetes": [
    {
      "apiVersion": "v1",
      "kind": "namespace",
      "executeHookOnEvent": [
        "Added"
      ]
    }
  ]
}
EOF
}

hook::trigger() {
  # ignore Synchronization for simplicity
  # TODO: check each namespace in .[0].objects
  type=$(jq -r '.[0].type' $BINDING_CONTEXT_PATH)
  if [[ $type == "Synchronization" ]] ; then
    echo Got Synchronization event
    exit 0
  fi

  echo "TRIGGER - namespace added"

  for namespace in $(jq -r '.[] | .object.metadata | select(.name == "default" | not ) | .name' $BINDING_CONTEXT_PATH);
  do
    for deployment in $(kubectl -n default get deployment -l deployment-copier=yes -o name);
    do
      kubectl -n default get $deployment -o json | \
        jq -r ".metadata.namespace=\"${namespace}\" |
                .metadata |= with_entries(select([.key] | inside([\"name\", \"namespace\", \"labels\"])))" \
        | kubectl::replace_or_create
    done
  done
}

common::run_hook "$@"

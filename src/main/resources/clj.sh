#!/usr/bin/env bash

# Extract java opts
java_opts=()
while [ $# -gt 0 ]
do
  case "$1" in
    -X*)
      java_opts+=("$1")
      shift
      ;;
    -D*)
      java_opts+=("$1")
      shift
      ;;
    -J*)
      java_opts+=("${1:2}")
      shift
      ;;
    *)
      break
      ;;
  esac
done

# Extract classpath opts
while [ $# -gt 0 ]
do
  case "$1" in
    -R*)
      resolve_aliases="${1:2}"
      shift
      ;;
    -C*)
      classpath_aliases="${1:2}"
      shift
      ;;
    -P*)
      classpath_overrides="${1:2}"
      shift
      ;;
    *)
      break
      ;;
  esac
done

# Find java executable
JAVA_CMD=$(type -p java)
if [[ ! -n "$JAVA_CMD" ]]; then
  if [[ -n "$JAVA_HOME" ]] && [[ -x "$JAVA_HOME/bin/java" ]]; then
    JAVA_CMD="$JAVA_HOME/bin/java"
  else
    >&2 echo "Couldn't find 'java'. Please set JAVA_HOME."
  fi
fi

# Find deps.edn and cache directory to use (either project or system)
clojure_dir="$HOME/.clojure"
system_deps="$clojure_dir/deps.edn"
system_cache_dir="$clojure_dir/.cpcache"
project_deps=deps.edn
project_cache_dir=.cpcache

# If project deps.edn is missing, use system deps
if [[ ! -f "$project_deps" ]]; then
  project_deps="$system_deps"
  project_cache_dir="$system_cache_dir"
fi

# Construct location of cached classpath file
if [[ -n "$resolve_aliases" ]]; then
  libs_root="$project_cache_dir/$resolve_aliases"
else
  libs_root="$project_cache_dir/default"
fi
libs_file="$libs_root.libs"

if [[ -n "$classpath_aliases" ]]; then
  cp_file="$libs_root/$classpath_aliases.cp"
else
  cp_file="$libs_root/default.cp"
fi

# Check cached cp file - if needed, make a new one
if [ ! -f "$cp_file" ] || [ ! -f "$libs_file" ] || [ "$libs_file" -nt "$cp_file" ] || [ "$project_deps" -nt "$cp_file" ]; then
  tools_cp=$(cat "$clojure_dir/deptools.cp")
  tools_args=()

  if [[ -n "$resolve_aliases" ]]; then
    tools_args+=("-R$resolve_aliases")
  fi
  if [[ -n "$classpath_aliases" ]]; then
    tools_args+=("-C$classpath_aliases")
  fi
  if [[ -n "$classpath_overrides" ]]; then
    tools_args+=("-P$classpath_overrides")
  fi

  cp=$("$JAVA_CMD" -Xmx256m -classpath "$tools_cp" clojure.main -m clojure.tools.deps.alpha.makecp "$project_deps" "$project_cache_dir" "${tools_args[@]}")
else
	cp=$(cat "$cp_file")
fi

# Launch!
rlwrap -r -q '\"' -b "(){}[],^%3@\";:'" "$JAVA_CMD" "${java_opts[@]}" -classpath "$cp" clojure.main "$@"

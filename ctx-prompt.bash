# ctx-completion.bash — tab completion for `ctx`
# Source it or drop it into /etc/bash_completion.d
# Requires bash >= 4.0

# --------------------------------- helpers -----------------------------------

# top-level verbs
__ctx_commands="init show status add rm merge-base version help"

# true if we’re inside a Git repo
__ctx_in_git_repo() {
	git rev-parse --git-dir >/dev/null 2>&1
}

# complete refs (branches, tags, remotes)
__ctx_complete_git_refs() {
	COMPREPLY=()
	if __ctx_in_git_repo; then
		local refs
		refs=$(git --no-pager for-each-ref \
			--format='%(refname:short)' \
			refs/heads refs/remotes refs/tags 2>/dev/null)
		mapfile -t COMPREPLY < <(compgen -W "$refs" -- "$cur")
	fi
}

# complete paths from ctx status
__ctx_complete_paths() {
	COMPREPLY=()
	local paths=
	# Extract paths from ctx status output (lines starting with tab after "Paths:")
	paths=$(ctx status 2>/dev/null | sed -n '/^Paths:/,/^[^[:space:]]/ { /^[[:space:]]/ p }' | sed 's/^[[:space:]]*//')
	if [[ -n "$paths" ]]; then
		mapfile -t COMPREPLY < <(compgen -W "$paths" -- "$cur")
	fi
}

# -------------------------------- dispatcher ---------------------------------

_ctx() {
	local cur=${COMP_WORDS[COMP_CWORD]}
	local cword=$COMP_CWORD

	# verbs after `ctx`
	if ((cword == 1)); then
		mapfile -t COMPREPLY < <(compgen -W "$__ctx_commands" -- "$cur")
		return
	fi

	# argument completion by verb
	case "${COMP_WORDS[1]}" in
	merge-base) __ctx_complete_git_refs ;; # git refs
	rm) __ctx_complete_paths ;;            # paths from ctx status
	*) COMPREPLY=() ;;                     # nothing more
	esac
}

# ---------------------------- hook into readline -----------------------------

# -o bashdefault : fall back to Bash’s own completion if we return nothing
# -o default     : keep filename completion semantics
complete -o bashdefault -o default -F _ctx ctx

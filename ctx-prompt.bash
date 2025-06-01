# ctx-completion.bash — tab completion for `ctx`
# Source it or drop it into /etc/bash_completion.d
# Requires bash >= 4.0

# --------------------------------- helpers -----------------------------------

# top-level verbs
__ctx_commands="init show status add rm merge-base help"

# true if we’re inside a Git repo
__ctx_in_git_repo() {
	git rev-parse --git-dir >/dev/null 2>&1
}

# complete paths
__ctx_complete_paths() {
	local IFS=$'\n'
	mapfile -t COMPREPLY < <(compgen -f -- "$cur")
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
	add | rm) __ctx_complete_paths ;;      # files / dirs
	merge-base) __ctx_complete_git_refs ;; # git refs
	*) COMPREPLY=() ;;                     # nothing more
	esac
}

# ---------------------------- hook into readline -----------------------------

# -o bashdefault : fall back to Bash’s own completion if we return nothing
# -o default     : keep filename completion semantics
complete -o bashdefault -o default -F _ctx ctx

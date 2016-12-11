__zplug::job::parallel::init()
{
    local    caller="${${(M)funcstack[@]:#__*__}:gs:_:}"
    local    is_parallel=false is_select=false
    local    filter repo starting_message
    local -a repos

    repos=( "$argv[@]" )

    case "$caller" in
        install)
            starting_message="install"
            # If no argument is given,
            # use non-installed plugins as an installation target
            if (( $#repos == 0 )); then
                repos=( $(__zplug::core::core::run_interfaces 'check' '--debug') )
                if (( $#repos == 0 )); then
                    __zplug::io::print::f \
                        --zplug --die \
                        "no packages to install\n"
                    return 1
                fi
            fi
            rm -f \
                "$_zplug_config[build_success]" \
                "$_zplug_config[build_failure]" \
                "$_zplug_config[build_timeout]" \
                "$_zplug_config[install_status]"
            touch "$_zplug_config[install_status]"
            ;;
        update)
            starting_message="update"
            zstyle -s ':zplug:core:update' 'select' is_select
            zstyle ':zplug:core:update' 'select' no
            rm -f \
                "$_zplug_config[build_success]" \
                "$_zplug_config[build_failure]" \
                "$_zplug_config[build_timeout]" \
                "$_zplug_config[update_status]"
            touch "$_zplug_config[update_status]"
            ;;
        status)
            starting_message="get remote status"
            zstyle -s ':zplug:core:status' 'select' is_select
            zstyle ':zplug:core:status' 'select' no
            rm -f "$_zplug_config[status_status]"
            touch "$_zplug_config[status_status]"
            ;;
        *)
            return 1
            ;;
    esac

    if (( $_zplug_boolean_true[(I)$is_select] )); then
        filter="$(
        __zplug::utils::shell::search_commands \
            "$ZPLUG_FILTER"
        )"
        if [[ -z $filter ]]; then
            __zplug::io::print::f \
                --die \
                --zplug \
                --error \
                --func \
                "There is no available filter in ZPLUG_FILTER\n"
            return 1
        fi
        repos+=( ${(@f)"$(echo "${(Fk)zplugs[@]}" | eval "$filter")"} )

        # Cace of type Ctrl-C
        if (( $#repos == 0 )); then
            return 1
        fi
    fi

    if (( $#repos == 0 )); then
        repos=( "${(k)zplugs[@]:gs:@::}" )
    fi

    # Check the number of arguments
    if (( $#repos > 1 )); then
        is_parallel=true
    fi

    for repo in "${repos[@]}"
    do
        if ! __zplug::base::base::zpluged "$repo"; then
            __zplug::io::print::f \
                --die \
                --zplug \
                "$repo: no such package\n"
            return 1
        fi
    done

    # Suppress outputs
    setopt nonotify nomonitor
    # Hide the cursor
    tput civis

    __zplug::io::print::f \
        --zplug \
        "Start to %s %d plugin${is_parallel:+"s"} %s\n\n" \
        "$starting_message" \
        $#repos \
        "${is_parallel:+"in parallel"}"

    reply=("$repos[@]")
}

__zplug::job::parallel::deinit()
{
    local caller="${${(M)funcstack[@]:#__*__}:gs:_:}"

    case "$caller" in
        update)
            if (( ${(k)#status_codes[(R)$_zplug_status[failure]]} == 0 )); then
                printf "$fg_bold[default] ==> Updating finished successfully!$reset_color\n"
            else
                printf "$fg_bold[red] ==> Updating failed for following packages:$reset_color\n"
                # Listing the packages that have failed to update
                for repo in "${(k)status_codes[@]}"
                do
                    if [[ $status_codes[$repo] == $_zplug_status[failure] ]]; then
                        printf " - %s\n" "$repo"
                    fi
                done
            fi
            # Run rollback if hook-build failed
            __zplug::job::rollback::message
            ;;
        install)
            if (( ${(k)#status_codes[(R)$_zplug_status[failure]]} == 0 )); then
                printf "$fg_bold[default] ==> Installation finished successfully!$reset_color\n"
            else
                printf "$fg_bold[red] ==> Installation failed for following packages:$reset_color\n"
                # Listing the packages that have failed to install
                for repo in "${(k)status_codes[@]}"
                do
                    if [[ $status_codes[$repo] == $_zplug_status[failure] ]]; then
                        printf " - %s\n" "$repo"
                    fi
                done
            fi
            # Run rollback if hook-build failed
            __zplug::job::rollback::message
            ;;
        status)
            if (( ${(k)#status_codes[(R)$_zplug_status[out_of_date]]} == 0 )); then
                printf "$fg_bold[default] ==> All packages are up-to-date!$reset_color\n"
            else
                printf "$fg_bold[red] ==> Run 'zplug update'. These packages are local out of date:$reset_color\n"
                # Listing the packages that have failed to install
                for repo in "${(k)status_codes[@]}"
                do
                    if [[ $status_codes[$repo] == $_zplug_status[out_of_date] ]]; then
                        printf " - %s\n" "$repo"
                    fi
                done
            fi
            ;;
    esac

    # Display the cursor
    tput cnorm
}
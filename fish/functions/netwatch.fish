function netwatch --description 'Monitor connectivity to 1.1.1.1 with macOS sound alerts'
    if test (uname -s) != Darwin
        echo 'netwatch: requires macOS (ping -W in milliseconds and afplay).' >&2
        return 1
    end

    set -l previous ''
    set -l current
    while true
        if ping -n -c 1 -W 500 1.1.1.1 >/dev/null 2>&1
            set current online
        else
            set current offline
        end

        if test "$current" != "$previous"
            echo (date +%T)" $current"
        end

        if test "$current" = offline
            afplay /System/Library/Sounds/Sosumi.aiff; or return $status
        else if test "$previous" = offline
            afplay /System/Library/Sounds/Glass.aiff; or return $status
        end

        set previous "$current"
        sleep 0.2; or return $status
    end
end

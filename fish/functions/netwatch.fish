function netwatch --description 'Monitor HTTPS connectivity with macOS sound alerts'
    if test (uname -s) != Darwin
        echo 'netwatch: requires macOS (afplay).' >&2
        return 1
    end

    set -l state unknown
    set -l failures 0
    set -l successes 0
    while true
        if curl -q -fs -o /dev/null --connect-timeout 2 --max-time 3 https://www.apple.com/; or curl -q -fs -o /dev/null --connect-timeout 2 --max-time 3 https://www.google.com/
            set failures 0
            set successes (math $successes + 1)
            if test "$successes" -ge 2; and test "$state" != online
                echo (date +%T)" HTTPS通信可能"
                if test "$state" = offline
                    afplay /System/Library/Sounds/Glass.aiff; or return $status
                end
                set state online
            end
        else
            set successes 0
            set failures (math $failures + 1)
            if test "$failures" -ge 3
                if test "$state" != offline
                    echo (date +%T)" 両方の監視先へHTTPS接続できません"
                end
                set state offline
            end
        end

        if test "$state" = offline
            afplay /System/Library/Sounds/Sosumi.aiff; or return $status
        end

        sleep 0.5; or return $status
    end
end

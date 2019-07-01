#!/bin/bash

#########################################
#                                       #
#         Show configured menu          #
#                                       #
#########################################

multiselect() {

    # the value return (passed in param)
    local retval=$1
    # The different choice we can select
    local -n options=$2
    # The default choice pre checked
    local -n defaults=$3

    # little helpers for terminal print control and key input
    ESC=$( printf "\033")
    cursor_blink_on()   { printf "$ESC[?25h"; }
    cursor_blink_off()  { printf "$ESC[?25l"; }
    cursor_to()         { printf "$ESC[$1;${2:-1}H"; }
    print_inactive()    { printf "$2   $1 "; }
    print_active()      { printf "$2  $ESC[7m $1 $ESC[27m"; }
    get_cursor_row()    { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
    key_input()         {
      local key
      IFS= read -rsn1 key 2>/dev/null >&2
      if [[ $key = ""      ]]; then echo enter; fi;
      if [[ $key = $'\x20' ]]; then echo space; fi;
      if [[ $key = $'\x71' ]]; then echo quit; fi;
      if [[ $key = $'\x1b' ]]; then
        read -rsn2 key
        if [[ $key = [A ]]; then echo up;    fi;
        if [[ $key = [B ]]; then echo down;  fi;
      fi
    }

    toggle_option() {
      local arr_name=$1
      eval "local arr=(\"\${${arr_name}[@]}\")"
      local option=$2
      if [[ ${arr[option]} == true ]]; then
        arr[option]=false
      else
        arr[option]=true
      fi
      eval $arr_name='("${arr[@]}")'
    }

    local selected=()

    # Copy default in the select var
    for ((i=0; i<${#options[@]}; i++)); do
      selected+=("${defaults[i]}")
      printf "\n"
    done

    # determine current screen position for overwriting the options
    local lastrow=`get_cursor_row`
    local startrow=$(($lastrow - ${#options[@]}))

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    local active=0
    while true; do
        # print options by overwriting the last lines
        local idx=0
        for option in "${options[@]}"; do
            local prefix="[ ]"
            if [[ ${selected[idx]} == true ]]; then
              prefix="[x]"
            fi

            cursor_to $(($startrow + $idx))
            if [ $idx -eq $active ]; then
                print_active "$option" "$prefix"
            else
                print_inactive "$option" "$prefix"
            fi
            ((idx++))
        done

        # user key control
        case `key_input` in
            space)  toggle_option selected $active;;
            enter)  break;;
            quit)   exit 0;;
            up)     ((active--));
                    if [ $active -lt 0 ]; then active=$((${#options[@]} - 1)); fi;;
            down)   ((active++));
                    if [ $active -ge ${#options[@]} ]; then active=0; fi;;
        esac
    done

    # cursor position back to normal
    cursor_to $lastrow
    printf "\n"
    cursor_blink_on

    eval $retval='("${selected[@]}")'
}

#########################################
#                                       #
#    Load information from conf file    #
#                                       #
#########################################

# import file with all the configurations
INPUT=./projects.csv
# save the old separation char
OLDIFS=$IFS
# declare new separation char
IFS=","
# declare all necessary varaible array
declare -a label=()
declare -a default=()
declare -a cmd=()

# Concat all value in the array and do not save the first line (labelled)
{
    read
    while IFS=, read -r labelTmp defaultTmp cmdTmp pathTmp
    do
      if [[ $labelTmp == \#* ]]; then
          continue #skip the lines beginning with a `#`
      fi
      label+=($labelTmp)
      default+=($defaultTmp)
      cmd+=($cmdTmp)
    done
} < $INPUT
# reload the old separation char
IFS=$OLDIFS

multiselect result label default


# echo "${result[@]}"
for i in "${!result[@]}";
    do
        if ${result[$i]}; then
          echo "${cmd[$i]}"
          eval "${cmd[$i]}"
        fi
    done
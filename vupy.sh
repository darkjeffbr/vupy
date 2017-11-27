#!/bin/bash

VUPY_VM_FILE="/etc/vupy/vms"
_VUPY_LINE_SEPARATOR="%"
_VUPY_VM_SEPARATOR="_"
ERROR_CODE=1
SUCCESS_CODE=0
VAGRANT_FILE_NAME="Vagrantfile"

#Vupy main function
vupy(){
    command=$1
    commandArgs=${@:2}
    runCommandArgs=${@:1}

    __vupy_touch_vms_file_if_not_exists

    case $command in
        add)
            __vupy_add ${commandArgs[@]}
            ;;
        list)
            __vupy_list
            ;;
        delete)
            __vupy_delete ${commandArgs[@]}
            ;;
        check)
            __vupy_check ${commandArgs[@]}
            ;;
        up)
            __vupy_vagrant_run ${runCommandArgs[@]}
            ;;
        halt)
            __vupy_vagrant_run ${runCommandArgs[@]}
            ;;
        ssh)
            __vupy_vagrant_run ${runCommandArgs[@]}
            ;;
        reload)
            __vupy_vagrant_run ${runCommandArgs[@]}
            ;;
        cd)
            __vupy_cd ${commandArgs[@]}
            ;;
        running)
            __vupy_running ${commandArgs[@]}
            ;;
        help)
           __vupy_help
            ;;
        *)
            __vupy_help
            ;;
    esac
}

#create the vms files if not exists
__vupy_touch_vms_file_if_not_exists(){
    if [ ! -e $VUPY_VM_FILE ];then
        touch $VUPY_VM_FILE
    fi
}


#Split a given string variable
#by a char
# $1: String with the content
# $2: char to split
__vupy_split(){
    local content=$1
    local charPattern=$2
    local chIndex=0
    local splittedArray=()
    local splittedValue=''

    if [ "${#content}" -eq "0" ] || [ "${#charPattern}" -ne "1" ];then
        echo "Content must have at least 1 char and charPatern must have exactly 1 char"
        return $ERROR_CODE
    fi

    while [ $chIndex -le ${#content} ];do
        #When find the charPattern, then add the spllitedValue
        # > accumulated so far
        # > clean the spllitedValue
        # > skip charPattern char, by increasing the chIndex counter
        if [ "${content:$chIndex:1}" = "$charPattern" ];then    
            splittedArray+=($splittedValue)
            splittedValue=''
            ((chIndex++)) #Skip charPattern char
        fi
        
        splittedValue=$splittedValue${content:$chIndex:1}

        ((chIndex++))
        
    done

    #Add the last element splitted to the array
    #In case that there is something afther the last
    #charPattern char
    if [ ! -z "$splittedValue" ];then
        splittedArray+=($splittedValue)
    fi

    echo "${splittedArray[@]}"
}

#Check whether or not a given line is empty
__vupy_is_empty_line(){
    local line=$1;
    if [ '0' = "${#line}" ];then
        echo true
    else
        echo false
    fi
}

#Check whether or not a given line of vms file
#is a comment
__vupy_is_comment_line(){
    local line=$1;
    if [ '#' = "${line:0:1}" ];then
        echo true
    else
        echo false
    fi
}

#Read the content of vms file and prepare it
#to be formatted
__vupy_read_vm_file(){
    local file_content=""
    while IFS= read -r line
    do
        #Here Ignore the comments line
        if [ true = $(__vupy_is_comment_line $line) ];then
            continue
        fi

        #Ignore empty line
        if [ true = $(__vupy_is_empty_line $line) ];then
            continue
        fi

        #Replace space by underscore
        line=$(echo $line | sed -e 's/\ /_/g')

        if [ -z "${file_content}" ];then
            file_content=${line}
        else
            file_content=${file_content}$_VUPY_LINE_SEPARATOR${line}
        fi
    done < "$VUPY_VM_FILE"
    echo $file_content;
}

#Parse the content of vms file
#return the content as an array
#where each entry of the array is one
#line of the file
__vupy_parse_vms_to_struct(){
    
    local vm_file_content=$(__vupy_read_vm_file)

    if [ ${#vm_file_content} != 0 ];then
        echo "$(__vupy_split "${vm_file_content}" $_VUPY_LINE_SEPARATOR)"    
    fi
}

#print each vm struct 
#with the name and location of the Vagrantfile
__vupy_list(){

    declare -g vms_struct=( $(__vupy_parse_vms_to_struct) )

    if [ ${#vms_struct[@]} != 0 ];then
        for vm_struct in ${vms_struct[@]};do
        declare vm=( $(__vupy_split "${vm_struct}" $_VUPY_VM_SEPARATOR) )
        echo -e "${vm[0]}\t\t${vm[1]}"
    done
    fi

    return $SUCCESS_CODE
}

#Print the add help
__vupy_add_help(){
    echo 'Usage: vupy add NAME LOCATION'
    echo '  NAME: unique name of a Vagrant VM'
    echo '  LOCATION: location of the Vagrantfile'
    return $SUCCESS_CODE
}

#Write a new entry to vms file
# $1 vm name
# $2 location of the Vagrantfile
__vupy_add_to_vm_file(){
    echo "$1 $2" >> $VUPY_VM_FILE
}

#Add a new entry to the vms file
# $1 NAME
# $2 Vagrantfile LOCATION
__vupy_add(){
    if [ $# -lt 2 -o $# -gt 2 ];then
        __vupy_add_help
        return $ERROR_CODE
    fi

    local vmName=$1
    local vmLocation=$2

    if [ -n "$(__vupy_find_vm $vmName)" ];then
        echo "$vmName already exists"
        return $ERROR_CODE    
    fi

    __vupy_add_to_vm_file $vmName $vmLocation

    return $SUCCESS_CODE
}
#Print delete help menu
__vupy_delete_help(){
    echo 'Usage: vupy delete NAME'
    echo '  NAME: unique name of a Vagrant VM'
    return $SUCCESS_CODE
}

#Deletes an entry in the vms file
#which is identified by a vm name
__vupy_delete(){
    if [ $# -lt 1 -o $# -gt 1 ];then
        __vupy_delete_help
        return $ERROR_CODE
    fi

    local vmName=$1

    vm=($(__vupy_find_vm $vmName))

    if [ -z "$vm" ];then
        __vupy_vm_not_found $vmName
        return $ERROR_CODE
    fi

    local file_content=""
    while IFS= read -r line
    do
        if [[ $line == ${vmName}* ]];then
            continue
        fi

        file_content=${file_content}${line}"\n"
    done < "$VUPY_VM_FILE"

    if [ ${#file_content} -gt 2 ];then
        local szFileContentNew=$(expr ${#file_content} - 2)
        file_content="${file_content:0:$szFileContentNew}" > "$VUPY_VM_FILE"
    fi

    echo -e "${file_content:0:$szFileContentNew}" > "$VUPY_VM_FILE"

    return $SUCCESS_CODE
}

#Checks if a given vm name exists
#and if its locations contains a 
#file named Vagrantfile
__vupy_check(){
    if [ $# -lt 1 -o $# -gt 1 ];then
        __vupy_check_help
        return $ERROR_CODE
    fi

    local vmName=$1

    vm=($(__vupy_find_vm $vmName))

    if [ -z "$vm" ];then
        __vupy_vm_not_found $vmName
        return $ERROR_CODE
    fi

    cd "${vm[1]}"

    foundVagrantfile="false"

    for file in $(ls);
    do
        if [ -f $file ];then
            if [ "$file" == "$VAGRANT_FILE_NAME" ];then
                foundVagrantfile="true"
            fi
        fi
    done

    if [ $foundVagrantfile == "true" ];then
        echo "ok"
    else
        echo "fail"
    fi

    cd - > /dev/null

    return $SUCCESS_CODE
}

#Main vupy help message
#list all the commands supported
__vupy_help(){
    echo "vupy command line vagrant utility tool"
    echo "Usage: vupy [ add | list | delete | check | up | halt | reload | ssh | cd | help ]"
    echo ""
    echo "add: Add a new vagrant virtual machine to vms file"
    echo "syntax: vupy add NAME LOCATION"
    echo "NAME: unique name of the virtual machine"
    echo "LOCATION: Location of the Vagrantfile"
    echo ""
    echo "list: Show the vm names and the location of the Vagrantfile"
    echo "syntax: vupy list"
    echo ""
    echo "delete: Delete an entry in the vms file"
    echo "syntax: vupy delete NAME"
    echo "NAME: unique name of the virtual machine"
    echo ""
    echo "check: Check if the location of a given virtual machine contains a Vagrantfile"
    echo "syntax: vupy check NAME"
    echo "NAME: unique name of the virtual machine"
    echo ""
    echo "up: Starts a Vagrant virtual machine"
    echo "syntax: vupy up NAME"
    echo "NAME: unique name of the virtual machine"
    echo ""
    echo "halt: Shutdown a Vagrant virtual machine"
    echo "syntax: vupy halt NAME"
    echo "NAME: unique name of the virtual machine"
    echo ""
    echo "reload: Reloads a Vagrant virtual machine"
    echo "syntax: vupy reload NAME"
    echo "NAME: unique name of the virtual machine"
    echo ""
    echo "halt: SSH into a Vagrant virtual machine"
    echo "syntax: vupy ssh NAME"
    echo "NAME: unique name of the virtual machine"
    echo ""
    echo "cd: Change to the location folder of a vm"
    echo "syntax: vupy cd NAME"
    echo "NAME: unique name of the virtual machine"
    echo ""
    echo "help: Print this help menu"
    echo "syntax: vupy help"
}

#Print check command help information
__vupy_check_help(){
    echo "No VM name specified"
    return $ERROR_CODE
}

#Print run command help information
__vupy_run_help(){
    echo "No VM name specified"
    return $ERROR_CODE
}

#Print cd command help information
__vupy_cd_help(){
    echo "No VM name specified"
    return $ERROR_CODE
}

#Read the vms file and looking for a vm
#by name
__vupy_find_vm(){
    local vmName=$1
    declare vms_struct=( $(__vupy_parse_vms_to_struct) )
    local vmFound

    for vm_struct in ${vms_struct[@]};do
        
        declare vm=( $(__vupy_split "${vm_struct}" $_VUPY_VM_SEPARATOR) )

        if [ $vmName = ${vm[0]} ];then
            vmFound=(${vm[@]})
        fi
    done

    echo ${vmFound[@]};
}

#Vagrant up command
__vupy_vagrant_up_command(){
    echo "vagrant up --provider virtualbox"
}

#Vagrant halt command
__vupy_vagrant_halt_command(){
    echo "vagrant halt"
}

#Vagrant reload command
__vupy_vagrant_reload_command(){
    echo "vagrant reload"
}

#Vagrant ssh command
__vupy_vagrant_ssh_command(){
    echo "vagrant ssh"
}

#Vagrant status command
__vupy_vagrant_status_command(){
    echo "vagrant status"
}

__vupy_vm_not_found(){
    echo  "$1 not found"
    return $ERROR_CODE
}

#Run a vagrant up or halt command
__vupy_vagrant_run(){

     if [ $# -lt 2 -o $# -gt 2 ];then
        __vupy_run_help
        return $ERROR_CODE
    fi

    local vupy_grant_command="__vupy_vagrant_$1_command"
    local vagrant_command=$(${vupy_grant_command})

    local vmName=$2

    vm=($(__vupy_find_vm $vmName))

    if [ -z "$vm" ];then
        __vupy_vm_not_found $vmName
        return $ERROR_CODE
    fi
    cd "${vm[1]}"
    #Run the vagrant command
    $vagrant_command
    cd - > /dev/null

    return $SUCCESS_CODE
}

#Change the actual directory to 
#location of a given vagrant vm
__vupy_cd(){

    if [ $# -lt 1 -o $# -gt 1 ];then
        __vupy_cd_help
        return $ERROR_CODE
    fi
    local vmName=$1

    vm=($(__vupy_find_vm $vmName))

    if [ -z "$vm" ];then
        __vupy_vm_not_found $vmName
        return $ERROR_CODE
    fi
    cd "${vm[1]}"

    return $SUCCESS_CODE
}

#List all running vagrant vm
#Or if a VM is specified then
#show if this vm is running
__vupy_running(){
    if [ $# -lt 1 ];then
         
        declare -g vms_struct=( $(__vupy_parse_vms_to_struct) )

        if [ ${#vms_struct[@]} != 0 ];then
            for vm_struct in ${vms_struct[@]};do
                declare vm=( $(__vupy_split "${vm_struct}" $_VUPY_VM_SEPARATOR) )

                cd "${vm[1]}"
                #Run the vagrant command
                $(__vupy_vagrant_status_command) | grep default                
                cd - > /dev/null

                #echo -e "${vm[0]}\t\t${vm[1]}"
            done
        else
            echo -e "No VM found\n\nTry:\n\tvupy add"
        fi

    else
   
        echo "....."

    fi

}

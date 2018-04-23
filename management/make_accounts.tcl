#!/usr/bin/expect

## make_accounts.tcl 
## expect script to automate account creation in datacenter.

## DANGER!  Comment this out unless debugging.  If you 
## don't, your plaintext passwords will be saved in file.
## use with /opt/mlb/bin/expect -d to troubleshoot.
#log_file -a .make_accounts.debug.txt

## Source common procedures.
source /opt/expect/common.tcl

## Grab list of hostlists.
set hostlists [return_hostlists]

## Determine name of script for accounting purposes.
set scriptname [file tail $argv0]

## Usage.
if {$argc != 3} {
  puts stderr "Usage: $scriptname \[username\] \[hostlist\] \[timeout\]"
  puts stderr "Options:"
  puts stderr "  \[username\] is the name of the user invoking sudo."
  puts stderr "  \[hostlist\] is the name of one of the following:" 
  puts stderr "  $hostlists"
  puts stderr "  \[timeout\]  is a numeric value."
  exit
} else {
  set sudo_user [lindex $argv 0]
  set hostlist  [lindex $argv 1]
  set timeout   [lindex $argv 2]    
}

## PROCEDURES
proc make_account {sudo_user sudo_passwd host} {
  set prompt "\[$%\#\>]" ;
  global useradd_cmd
  global groupadd_cmd
  global username

  ## Find local ssh
  if {[file exists /bin/ssh]} {
    set ssh_binary "/bin/ssh"
  } elseif {[file exists /usr/local/bin/ssh]} {
    set ssh_binary "/usr/local/bin/ssh"
  }
  ## Spawn an ssh connection.
  spawn $ssh_binary -l $sudo_user $host 

  ## Check for key exchange prompt.
  expect -re "(.*)Host key verification failed" {
    error "$host: It is possible that the RSA host key has changed."
  } -re "\(yes\/no\)" {
    send -- "yes\r"
    set lastspawn $spawn_id
  }
  ## If key exchange occurred, continue with that spawn_id.
  if {[info exists lastspawn] == 1} {
    set spawn_id $lastspawn
  }
  expect -re "($sudo_user@$host's password|^Password|\nPassword):" {
    send -- "$sudo_passwd\r"
    expect -re "Last login(.*)\n(.*)$prompt" {
      ## Send our groupadd command 
      send -- "sudo $groupadd_cmd\r"
      ## If we have used sudo on this host, we won't be prompted for passwd.
      expect -re "(.*)$prompt" {
        send -- "sudo $useradd_cmd\r"
        expect -re "(.*) blocks\n" {
          expect "Account successfully created for $username on $host."
          close
          wait
          return 1
        } -re "(.*)is already in use.  Choose another." {
          close
          wait
          error "account $username is already in use on $host."
        }
      } -re "(.*)is already in use.  Choose another." {
        close
        wait
        error "group $username is already in use on $host."
      }
      ## Otherwise we have to send sudo password...
      expect -re "($sudo_user@$host's password|^Password|\nPassword):" {
        send -- "$sudo_passwd\r"
        expect -re "(.*)$prompt" {
          send -- "sudo $useradd_cmd\r"
          expect -re "(.*) blocks\n" {
            expect "Account successfully created..."
            close
            wait
            return 1
          }
        } -re "(.*)is already in use.  Choose another." {
          close
          wait
          error "group is already in use..."
        }
      }
    } -re "assword:" {
      close
      wait
      error "$host: wrong passwd"
    }
  }
}
 
proc collect_user_info {} {
  ## This procedure collects information about the new user account.
  ## It collects and builds arguments for useradd and groupadd commands.
  ## Procedures can't return multiple values; instead use global variables.
  global useradd_cmd
  global groupadd_cmd
  global username

  ## We collect information about new user until syntax for commands looks
  ## correct.  This will give us a chance to revise them before running.
  set timeout -1
  set looksgood "n"
  set answer "n"
  while {[string compare $looksgood "n"] == 0} {
    ## What is the user's full name?
    while {[string compare $answer "n"] == 0} {
      send_user "\n"
      send_user "What is the user's full name?\n"
      send_user "(Required) Used to construct comment string in passwd entry.\n"
      send_user "Full Name: "
      expect_user -re "(.*)\n"
      set fullname $expect_out(1,string)
      if {([llength $fullname] == 0)} {
        puts "*** ERROR ***: You must supply a full name."    
        set answer "n"
      } else {
        set answer "y"      
      }
    }
    set answer "n"

    ## What is the role of the user?
    send_user "\n"
    send_user "What MLBAM group does the user work for?  (i.e. FET, DBA, Tavant, etc.)\n"
    send_user "(Optional) Used to construct comment string in passwd entry.\n"
    send_user "MLBAM Group: "
    expect_user -re "(.*)\n"
    set role $expect_out(1,string)

    ## What is the user's phone extension?
    send_user "\n"
    send_user "What is the user's phone extension or number? (i.e. x6162)\n"
    send_user "Used to construct comment string in passwd entry.\n"
    send_user "(Optional) Press enter to ignore.\n"
    send_user "Phone: "
    expect_user -re "(.*)\n"
    set phone $expect_out(1,string)
  
    ## Ask for UID and GID number.
    while {[string compare $answer "n"] == 0} {
      send_user "\n"
      send_user "Choose a unique number for UID and GID\n"
      send_user "Make sure it falls into proper UID/GID range for user role.\n"
      send_user "There is a wiki page describing the ranges of UIDs and GIDs.\n"
      send_user "(Required) Use bastion passwd as a reference point.\n"
      send_user "UID/GID: "
      expect_user -re "(.*)\n"
      set id $expect_out(1,string)
      if {([llength $id] == 0)} {
        puts "*** ERROR ***: You must supply a UID/GID number."
        set answer "n"
      } else {
        set answer "y"      
      }
    }
    set answer "n"    

    ## Ask for supplementary group membership.
    send_user "\n"
    send_user "Any supplementary unix group membership? (i.e. systems, dba, etc.)\n"
    send_user "(Optional) Press enter to ignore.\n"
    send_user "Supplementary Group: "
    expect_user -re "(.*)\n"
    set group $expect_out(1,string)
  
    ## What is the desired shell?
    send_user "\n"
    send_user "What is desired unix shell? (defaults to /bin/bash)\n"
    send_user "Press enter for default shell.\n"
    send_user "shell: "
    expect_user -re "(.*)\n"
    set shell $expect_out(1,string)
    if {([llength $shell] == 0)} {
      set shell "/bin/bash"
    }
  
    ## What is the desired username?
    while {[string compare $answer "n"] == 0} {
      send_user "\n"
      send_user "What is desired unix username?\n"
      send_user "Unix Username: "
      expect_user -re "(.*)\n"
      set username $expect_out(1,string)
      if {([llength $username] == 0)} {
        puts "*** ERROR ***: You must supply a unix username."
        set answer "n"
      } else {
        set answer "y"      
      }
    }
    set answer "n"        

    ## Set comment.
    if {([llength $role] > 0) && ([llength $phone] > 0)} {
      set comment "$fullname, $role, $phone"  
    } 
    if {([llength $role] > 0) && ([llength $phone] == 0)} {
      set comment "$fullname, $role"
    } 
    if {([llength $role] == 0) && ([llength $phone] > 0)} {
      set comment "$fullname, $phone"
    } 
    if {([llength $role] == 0) && ([llength $phone] == 0)} {
      set comment "$fullname"
    } 

    set comment "$fullname"

    ## Set groupadd command syntax.
    set groupadd_cmd "/usr/sbin/groupadd -g $id $username"

    ## Set username command syntax.
    if {([llength $group] > 0)} {
      set useradd_cmd "/usr/sbin/useradd -u $id -g $id -G $group -c \"$comment\" -d /export/home/$username -m -s $shell $username"
    } else {
      set useradd_cmd "/usr/sbin/useradd -u $id -g $id -c \"$comment\" -d /export/home/$username -m -s $shell $username"
    }
    puts "\nHere is the syntax for the groupadd and useradd command:\n"
    puts "GROUPADD COMMAND: $groupadd_cmd"
    puts "USERADD COMMAND:  $useradd_cmd"
    send_user "\nDoes the syntax for these commands look good?  (y/n) "
    expect_user -re "(.*)\n"
    set looksgood $expect_out(1,string)
    set answer "n"
  }
  ## Return 1 for success, 0 for failure.
  ## We can add option to break and exit at end of collect.
  ## If you break, it will return 1.
  if {[string compare $looksgood "y"] == 0} {
    return 1
  } else {
    return 0
  }
}

## END PROCEDURES

## MAIN LOGIC

if {[catch {set hosts [parse_list "hostlists/$hostlist"]} out]} {
  puts $out
} else {
  ## This should enable/disable echo'ing of chars
  #log_user 0 
  log_user 1

  ## Initialize three global variables
  set useradd_cmd ""
  set groupadd_cmd ""
  set username ""

  ## collect_user_info should return 0 or 1.
  if {[collect_user_info]} { 
    puts "Done collecting user info for $username"
  }
  puts "What is your password for sudo access?"
  set sudo_passwd [passwd_prompt]
  lappend error_buffer "# $scriptname $sudo_user $hostlist $timeout"
  foreach host $hosts {
    ## Basically, any custom expect procedure can be inserted here.
    if {[regexp {^[^\#]} $host]} {
      if {[catch {make_account $sudo_user $sudo_passwd $host} out]} {
        lappend error_buffer "# $host: $out"
        lappend error_buffer $host
        puts $out
      } else {
        puts "account created."
      }
    }
  }
  if {[catch {print_error_report $sudo_user $scriptname $error_buffer} out]} {
    puts $out
  } else {
    exit
  }
}

## END CONTROLLING LOGIC


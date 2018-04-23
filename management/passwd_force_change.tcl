#!/usr/bin/expect

## passwd_force_change.tcl 
## Simple script to brutally force a user's password change.

## Source common procedures.
source /opt/expect/common.tcl

## Determine name of script for accounting purposes.
set scriptname [file tail $argv0]

## DANGER!  Comment this out unless debugging.  If you 
## don't, your plaintext passwords will be saved in file.
## use with expect -d to troubleshoot.
#log_file -a .${scriptname}.debug.txt

## Grab list of hostlists.
set hostlists [return_hostlists]

## Usage.
if {$argc != 3} {
  puts "Usage: $scriptname \[sudo_user\] \[hostlist\] \[timeout\]"
  puts "Options:"
  puts "  \[sudo_user\] is the name of the user invoking sudo."
  puts "  \[hostlist\] is the name of one of the following:" 
  puts "  $hostlists"
  puts "  \[timeout\] is a number."
  exit
} else {
  set sudo_user [lindex $argv 0]
  set hostlist  [lindex $argv 1]
  set timeout   [lindex $argv 2]
}

## PROCEDURES HERE
proc force_passwd_change {sudo_user sudopw user passwd host} {
  ## This assumes most users have $%#> in their shell prompt.
  set prompt "\[\$%\#\>]"

  ## Find local ssh
  if {[file exists /bin/ssh]} {
    set ssh_binary "/bin/ssh"
  } elseif {[file exists /usr/local/bin/ssh]} {
    set ssh_binary "/usr/local/bin/ssh"
  }

  ## Spawn an ssh connection.
  spawn $ssh_binary -l $sudo_user $host 

  ## Puke if we see that a host key has changed.
  expect -re "(.*)Host key verification failed" {
    close; wait
    error "$host: It is possible that the RSA host key has changed."
  ## Check for key exchange prompt.
  } -re "\(yes\/no\)" {
    send -- "yes\r"
    set lastspawn $spawn_id
  }
  ## If key exchange occurred, continue with that spawn_id.
  if {[info exists lastspawn] == 1} {
    set spawn_id $lastspawn
  }
  expect { 
    timeout {
      error "$host: timed out: can't contact host"
    } -re "($sudo_user@$host's password|^Password|\nPassword):" {
      send -- "$sudopw\n"
      ## If you've never logged in before, you won't get "Last Login"
      expect -re "Last login(.*)\n(.*)$prompt" {
        send -- "sudo passwd $user\n"
        ## If we've already sudo'ed recently on this host, we
        ## won't be prompted for our (cached) password. 
        expect -re "\nNew Password:" {
          set spawn_id [change_passwd $user $passwd]
          set spawn_id [passwd_never_expires $user]
          send -- "exit\n"
          expect "Connection to (.*) closed.\r\n"
          wait
          return 1
        } -re "User unknown:(.*)\r\nPermission denied\r\n" {
          error "$host: User unknown."
          wait; close
        }
        ## Most likely you will be asked for your sudo password.
        expect -re "($sudo_user@$host's password|^Password|\nPassword):" {
          send -- "$sudopw\n"          
          expect -re "\nNew Password:" {
            set spawn_id [change_passwd $user $passwd]
            set spawn_id [passwd_never_expires $user]
            send -- "exit\n"
            expect "Connection to (.*) closed.\r\n"
            wait
            return 1
          } -re "User unknown:(.*)\r\nPermission denied\r\n" {
            error "$host: User unknown."
            wait; close
          }
        }
      } -re "($sudo_user@$host's password|^Password|\nPassword):" {
        error "$host: wrong passwd"
        wait; close
      }
    }
  }
}

proc change_passwd {user passwd} {
  upvar spawn_id spawn_id
  send -- "$passwd\n" 
  expect -re "Re-enter new Password:"
  send -- "$passwd\n" 
  expect "passwd: password successfully changed for $user\r\n(.*)"
  return $spawn_id
}

proc passwd_never_expires {user} {
  upvar spawn_id spawn_id
  send -- "sudo passwd -x -1 $user\n"
  expect "passwd: password information changed for $user\r\n(.*)"
  return $spawn_id
}

## END PROCEDURES

## MAIN LOGIC

if {[catch {set hosts [parse_list "hostlists/$hostlist"]} out]} {
  puts $out
} else {
  ## This should enable/disable echo'ing of chars
  #log_user 0 
  log_user 1
  puts "What is your password for sudo access?"
  set sudopw [passwd_prompt]
  puts "What user gets their password changed?"
  set user [input_prompt User]
  puts "What is the new password for ${user}?"
  set newpw [passwd_prompt]
  lappend error_buffer "# $scriptname $sudo_user $hostlist $timeout"
  foreach host $hosts {
    ## Basically, any custom expect procedure can be inserted here.
    ## Skip over commented lines in hostlists.
    if {[regexp {^[^\#]} $host]} {
      if {[catch {force_passwd_change $sudo_user $sudopw $user $newpw $host} out]} {
        lappend error_buffer "# $host: $out"
        lappend error_buffer $host
        puts $out
      } else {
        puts "password changed for $user on $host."
      }
    }
  }
  if {[catch {print_error_report $sudo_user $scriptname $error_buffer} out]} {
    puts $out
  } 
}

## END CONTROLLING LOGIC

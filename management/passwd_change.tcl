#!/usr/bin/expect

## passwd_change.tcl 
## This is a rewrite of passwd_change.tcl with many improvements.
## This script was the original expect script that created the 
## framework (/opt/expect/common.tcl) for all the other scripts.  
##
## It asks you to enter up to three old passwords and a new password.  
## It then spawns ssh connections to all hosts, logs in and changes 
## your password, one host at a time.  It handles expired passwords 
## as well, and works on both Solaris 9 and 10 (DC1 and DC2).
##  
## This script is useful if your password is out of sync or expired
## on many different hosts.  Use this script to sync your passwords.
## Then shadow_fix.tcl them so they don't expire.

## DANGER!  Comment this out unless debugging.  If you 
## don't, your plaintext passwords will be saved in file.
## use with expect -d to troubleshoot.
#log_file -a .passwd_change.tcl.debug.txt

## source common procedures.
source /opt/expect/common.tcl

## Grab list of hostlists.
set hostlists [return_hostlists]

## Determine name of script for accounting purposes.
set scriptname [file tail $argv0]

## Usage.
if {$argc != 3} {
  puts "Usage: $scriptname \[username\] \[hostlist\] \[timeout\]"
  puts "Options:"
  puts "  \[username\] is the name of the user changing their password."
  puts "  \[hostlist\] is the name of one of the following:" 
  puts "  $hostlists"
  puts "  \[timeout\] is a numeric value."
  exit
} else {
  set username [lindex $argv 0]
  set hostlist [lindex $argv 1]
  set timeout  [lindex $argv 2]
}

## PROCEDURES HERE
proc collect_passwds {} {
  set timeout -1
  set count 0
  set answer y
  while {[string compare $answer "y"] == 0} {
    incr count
    lappend passwdlist [passwd_prompt]
    if {$count == 3} {    
      set answer "n"
    } else {
      send_user "\nAdd another? (y/n) "
      expect_user -re "(.*)\n"
      set answer $expect_out(1,string)
    }
    if {[string compare $answer "n"] == 0} {
      puts ""
      return $passwdlist
    } else {
      set answer "y"
    }
  }
}

proc passwd_expires_9 {newpasswd host} {      
  upvar spawn_id spawn_id
  expect "New Password" {
    send -- "$newpasswd\r"  
    expect "Please try again" {
      close; wait
      error "$host: Your new password doesn't pass policy."
    } "Password in history list" {
      close; wait
      error "$host: Password in history list."          
    } "Re-enter new Password" {
      send -- "$newpasswd\r"  
      expect -re "closed(.*)" {
        close; wait
        return 1
      }
    }
  }
}

proc passwd_expires_10 {newpasswd host} {
  upvar spawn_id spawn_id
  ## It's important for the newline to be in front of the Password:
  expect "\nPassword: " {
    close; wait
    error "$host: Your new password doesn't pass policy."           
  } "Password in history list" {
    close; wait
    error "$host: Password in history list."          
  } "Re-enter new Password" {
    send -- "$newpasswd\r"      
    ### Should capture everything up to prompt before sending break.
    ### expect -re "sshd-kbdint: password successfully changed(.*)"
    expect -re "sshd-kbdint: password successfully changed(.*)" {
      close; wait
      return 1  
    }
  }
}

proc issue_passwd_command {username working newpasswd host} {
  ## grab spawn_id from invoking procedure
  upvar spawn_id spawn_id
  global prompt
  send -- "passwd\r"
  expect -re "\nEnter existing login password: "
  send -- "$working\r"  
  expect -re "\npasswd: Sorry: less than 7 days since the last change.(.*)\nPermission denied(.*)\n(.*)$prompt" {
    close; wait
    error "$host: less than 7 days."
  } "\nNew Password: " {
    send -- "$newpasswd\r"  
    expect -re "(.*)\nPlease try again(.*)\nNew Password: " {
      close; wait
      error "Your password doesn't pass policy."
    } -re "\npasswd: Password in history list.(.*)\nPlease try again(.*)\nNew Password: " {
      close; wait
      error "$host: Password is in history list."          
    } "\nRe-enter new Password: " {
      send -- "$newpasswd\r"  
      expect -re "\npasswd: password successfully changed for (.*)\n.*$prompt" {
        close; wait
        return 1
      }
    } 
  }          
}

proc change_passwd {username oldpasswdlist newpasswd host} {
  global prompt
  ## Find local ssh
  if {[file exists /bin/ssh]} {
    set ssh_binary "/bin/ssh"
  } elseif {[file exists /usr/local/bin/ssh]} {
    set ssh_binary "/usr/local/bin/ssh"
  }
  ## Spawn an ssh connection.
  spawn $ssh_binary -l $username $host 

  ## Check for key exchange prompt.
  expect -re "(.*)Host key verification failed" {
    close; wait
    error "$host: It is possible that the RSA host key has changed."
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
      close; wait
      error "$host: timed out: can't contact host"
    } 
    -re "($username@$host's password|^Password|\nPassword):" {
      ## Send first password.
      set working [lindex $oldpasswdlist 0]
      send -- "$working\r"
      expect -re "($username@$host's password|^Password|\nPassword):" {
        ## If that didn't work, send second password.
        if {[string compare [lindex $oldpasswdlist 1] ""]} {
          set working [lindex $oldpasswdlist 1]
          send -- "$working\r"
          expect -re "($username@$host's password|^Password|\nPassword):" {
            ## If that didn't work send third password.
            ## After three wrong passwords login fails.
            if {[string compare [lindex $oldpasswdlist 2] ""]} {
              set working [lindex $oldpasswdlist 2]
              send -- "$working\r"
              expect -re "New Password" {
                send -- "$newpasswd\r"
                return [passwd_expires_10 $newpasswd $host]
              } "existing login password" {
                send -- "$working\r"
                return [passwd_expires_9 $newpasswd $host]    
              } -re "Last login(.*)\n(.*)$prompt" {
                return [issue_passwd_command $username $working $newpasswd $host]
              } -re "(.*)interactive." {
                close; wait
                error "login failed."
              }
            ## If third password does not exist.
            } else {
              close; wait
              error "No more old passwords to try."
            }
          ## Continuing handling second password.
          } -re "New Password" {
            send -- "$newpasswd\r"
            return [passwd_expires_10 $newpasswd $host]
          } "existing login password" {
            send -- "$working\r"
            return [passwd_expires_9 $newpasswd $host]    
          } -re "Last login(.*)\n(.*)$prompt" {
            return [issue_passwd_command $username $working $newpasswd $host]
          }
        ## If second password does not exist.
        } else {
          close; wait
          error "No more old passwords to try."
        }
      ## Continue handling first password.
      } -re "New Password" {
        send -- "$newpasswd\r"
        return [passwd_expires_10 $newpasswd $host]
      } "existing login password" {
        send -- "$working\r"
        return [passwd_expires_9 $newpasswd $host]    
      } -re "Last login(.*)\n(.*)$prompt" {
        return [issue_passwd_command $username $working $newpasswd $host]
      }
    }
  }
}

## END PROCEDURES

## BEGIN MAIN LOGIC

## Call procedure and catch error if any.
if {[catch {set hosts [parse_list "hostlists/$hostlist"]} out]} {
  puts $out
} else {
  set prompt "\[\$%\#\>]"
  puts "Please enter your existing passwords."
  set oldpasswdlist [collect_passwds]
  puts "Please enter your new password."
  set newpasswd [passwd_prompt]
  lappend error_buffer "# $scriptname $username $hostlist $timeout"
  foreach host $hosts {
    ## Basically, any custom expect procedure can be inserted here.
    if {[regexp {^[^\#]} $host]} {
      if {[catch {change_passwd $username $oldpasswdlist $newpasswd $host} out]} {
        lappend error_buffer "# $host: $out"
        lappend error_buffer $host
        puts $out
      } else {
        puts "password changed for $username on $host."
      }
    }
  }
  if {[catch {print_error_report $username $scriptname $error_buffer} out]} {
    puts $out
  } 
}

## END MAIN LOGIC
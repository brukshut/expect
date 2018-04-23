#!/usr/bin/expect

## passwd_unlock.tcl 
## Simple script to fix force a user's password to never expire.

## DANGER!  Comment this out unless debugging.  If you 
## don't, your plaintext passwords will be saved in file.
## use with /opt/mlb/bin/expect -d to troubleshoot.
#log_file -a .pw_unlock.debug.txt

## source common procedures.
source /opt/expect/common.tcl

## Grab list of hostlists.
set hostlists [return_hostlists]

## Usage.
if {$argc != 3} {
  puts stderr "Usage: $argv0 \[sudouser\] \[hostlist\] \[timeout\]"
  puts stderr "Options:"
  puts stderr "  \[sudouser\] is the name of the user invoking sudo."
  puts stderr "  \[hostlist\] is the name of one of the following:" 
  puts stderr "    $hostlists"
  puts stderr "  \[timeout\]  is a numeric value."
  exit
} else {
  set sudo_user [lindex $argv 0]
  set hostlist  [lindex $argv 1]
  set timeout   [lindex $argv 2]
}

## PROCEDURES HERE
proc fix_shadow {sudo_user sudo_passwd account host} {
  ## Check location of ssh on host.
  if {[file exists /bin/ssh]} {
    set ssh_binary "/bin/ssh"
  } elseif {[file exists /usr/local/bin/ssh]} {
    set ssh_binary "/usr/local/bin/ssh"
  }
  spawn $ssh_binary $host "echo LOGIN ; sudo /bin/passwd -u $account"
  ## Check for key exchange prompt.
  expect -re "(.*)Host key verification failed" {
    error "$host: It is possible that the RSA host key has changed."
  } -re "\(yes\/no\)" {
    send -- "yes\r"
    set lastspawn $spawn_id
  }
  ## If lastspawn exists, set spawn_id to lastspawn.
  ## If key exchange occurred, continue with that spawn_id.
  if {[info exists lastspawn] == 1} {
    set spawn_id $lastspawn
  }
  expect { 
    timeout {
      error "$host: timed out: can't contact host"
    } -re "($sudo_user@$host's password|^Password|\nPassword):" {
      send -- "$sudo_passwd\n"
      expect -re "LOGIN(.*)Permission denied\r\n" {
        close
        wait
        error "$host: User unknown"       
      } -re "LOGIN(.*)assword:" {
        send -- "$sudo_passwd\n"
        expect -re "passwd: password information changed for $account" {
          close
          wait
          return 1
        }
      } -re "($sudo_user@$host's password|^Password|\nPassword):" {
        close
        wait
        error "$host: wrong passwd"
      }
    }
  }
}
## END PROCEDURES

## MAIN LOGIC

if {[catch {set hostlist [parse_list "hostlists/$hostlist"]} out]} {
  puts $out
} else {
  ## This should enable/disable echo'ing of chars
  log_user 0 
  #log_user 1

  puts "What is your password for sudo access?"
  set sudo_passwd [passwd_prompt]
  puts "What account are you unlocking?"
  set account [input_prompt Account]

  lappend error_buffer "# $argv0 $sudo_user $hostlist $timeout"
  foreach host $hostlist {
    if {[regexp {^[^\#]} $host]} {
      if {[catch {fix_shadow $sudo_user $sudo_passwd $account $host} out]} {
        lappend error_buffer "# $host: $out"
        lappend error_buffer $host
        puts $out
      } else {
        puts "shadow fixed for $account on $host."
      }
    }
  }
  if {[catch {print_error_report $sudo_user $argv0 $error_buffer} out]} {
    puts $out
  } else {
    exit
  }
}

## END CONTROLLING LOGIC

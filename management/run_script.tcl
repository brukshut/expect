#!/usr/bin/expect 

####
## $Id: run_script.tcl 208 2011-01-01 17:57:51Z cgough $
## Simple expect script to run a shell script across all webs.
####

## PROCEDURES HERE
## Source common procedures.
source /opt/expect/common.tcl

## Determine name of script for accounting purposes.
set scriptname [file tail $argv0]

## Grab list of hostlists.
set hostlists [return_hostlists]

## Usage.
if {$argc != 3} {
  puts stderr "Usage: $scriptname \[username\] \[hostlist\] \[timeout\]"
  puts stderr "Options:"
  puts stderr "  \[username\] is the user invoking sudo."
  puts stderr "  \[hostlist\] is the name of one of the following:" 
  puts stderr "  $hostlists"
  puts stderr "  \[timeout\]  is a numeric value."
  exit
} else {
  set sudo_user    [lindex $argv 0]
  set hostlist     [lindex $argv 1]
  set host_timeout [lindex $argv 2]
}

## Procedures here.
proc run_script {sudo_user sudo_passwd script host} {
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
      send -- "$sudo_passwd\n"
      ## If you've never logged in before, you won't get "Last Login"
      expect -re "Last login(.*)\n(.*)$prompt" {
        send -- "sudo $script\n"
        expect -re "DONE" {
          return 1
        } -re "FAIL" {
          close; wait
          error "FAIL"
        } -re "($sudo_user@$host's password|^Password|\nPassword):" {
          send -- "$sudo_passwd\n"          
          expect -re "DONE" {
            return 1
          } -re "FAIL" {
            close; wait
            error "FAIL"
          }
        }
      } -re "($sudo_user@$host's password|^Password|\nPassword):" {
        close; wait
        error "$host: wrong passwd"
      }
    }
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
  puts "What is your sudo password?"
  set sudo_passwd [passwd_prompt]
  ## Warn users.
  puts "YOU ARE RESPONSIBLE FOR USING THIS SCRIPT.  MAKE SURE YOUR SCRIPT WORKS!"
  set timeout -1
  set answer n
  while {[string compare $answer "n"] == 0} {
    puts "Where is the shell script located on the remote hosts? (Use quotes with any whitespace)."
    set script [input_prompt "Remote script"]
    puts "Here is the location of your remote script:"
    puts "HOST:$script"
    send_user "Does it look good? (y/n): "
    expect_user -re "(.*)\n"
    set response $expect_out(1,string)
    if {[string compare $response "y"] == 0} {
      set answer y
    } else {
      set answer n
    }   
  }
  set timeout $host_timeout
  lappend error_buffer "# $scriptname $sudo_user $hostlist $timeout"
  foreach host $hosts {
    ## Basically, any custom expect procedure can be inserted here.
    ## Skip over commented lines in hostlists.
    if {[regexp {^[^\#]} $host]} {
      if {[catch {run_script $sudo_user $sudo_passwd $script $host} out]} {
        lappend error_buffer "# $host: $out"
        lappend error_buffer $host
        puts $out
      } else {
        puts "$host:$script completed successfully."
      }
    }
  }
  if {[catch {print_error_report $sudo_user $scriptname $error_buffer} out]} {
    puts $out
  } 
}

## END MAIN LOGIC
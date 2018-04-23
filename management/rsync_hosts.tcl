#!/usr/bin/expect 

####
### $Id: rsync_hosts.tcl 245 2011-04-13 20:29:50Z cgough $
### Simple expect script to rsync content across hosts.
####

#### DANGER!  Comment this out unless debugging.  If you 
#### don't, your plaintext passwords will be saved in file.
#### use with expect -d to troubleshoot.
#log_file -a .rsync_hosts.tcl.debug.txt

#### Source common procedures.
source /opt/expect/common.tcl

#### Grab list of hostlists.
set hostlists [return_hostlists]

#### Usage.
if {$argc != 3} {
  puts stderr "Usage: $argv0 <username> <hostlist> <timeout>"
  puts stderr "<username> is the user invoking rsync."
  puts stderr "<hostlist> is the name of one of the following:" 
  puts stderr "           $hostlists"
  puts stderr "<timeout>  is a numeric value.  Use higher values"
  puts stderr "           for larger file transfers."
  exit
} else {
  set username       [lindex $argv 0]
  set hostlist       [lindex $argv 1]
  set rsync_timeout  [lindex $argv 2]
}

#### PROCEDURES HERE
proc rsync_host {username src_path dest_path rsync_path host password} {
  global rsync_timeout
  set timeout $rsync_timeout

  #### Find local rsync path
  if {[file exists /opt/sfw/bin/rsync]} {
    set rsync_binary "/opt/sfw/bin/rsync"
  } elseif {[file exists /opt/csw/bin/rsync]} {
    set rsync_binary "/opt/csw/bin/rsync"
  } elseif {[file exists /usr/local/bin/rsync]} {
    set rsync_binary "/usr/local/bin/rsync"
  } elseif {[file exists /bin/rsync]} {
    set rsync_binary "/bin/rsync"
  }
  spawn $rsync_binary -av --rsync-path=rsync $src_path $username@$host:$dest_path
  #### If host key mismatches, throw error and continue.
  #### Check for key exchange prompt.
  expect -re "(.*)Host key verification failed" {
    error "$host: It is possible that the RSA host key has changed."
  } -re "\(yes\/no\)" {
    send -- "yes\r"
    set lastspawn $spawn_id
  }
  #### If lastspawn exists, set spawn_id to lastspawn.
  #### If key exchange occurred, continue with that spawn_id.
  if {[info exists lastspawn] == 1} {
    set spawn_id $lastspawn
  }
  expect { 
    timeout {
      error "$host: timed out: can't contact host"
    } -re "($username@$host's password|^Password|\nPassword):" {
      send -- "$password\n"
      expect -re "speedup is(.*)\r\n" {
        close
        wait
        return 1
      } -re "(rsync: not found|No such file or directory)" {
        close
        wait
        if {[string compare $rsync_path "/opt/sfw/bin/rsync"] == 0} {
          rsync_host $username $src_path $dest_path "/usr/local/bin/rsync" $host $password
        } elseif {[string compare $rsync_path "/usr/local/bin/rsync"] == 0} {
          rsync_host $username $src_path $dest_path "/usr/sfw/bin/rsync" $host $password
        } elseif {[string compare $rsync_path "/usr/sfw/bin/rsync"] == 0} {
          rsync_host $username $src_path $dest_path "/opt/csw/bin/rsync" $host $password
        } else {[string compare $rsync_path "/opt/sfw/bin/rsync"] == 0} {
          rsync_host $username $src_path $dest_path "/bin/rsync" $host $password
        }
      } -re "($username@$host's password|^Password|\nPassword):" {
        error "$host: wrong password"
      }
    }
  }
}
#### END PROCEDURES

#### MAIN LOGIC
lappend error_buffer "#### rsync_hosts.tcl $username $hostlist $rsync_timeout"

puts "What is ${username}'s password?"
set password [passwd_prompt]
set error_info ""

#### This should be put in loop.  Ask user if rsync invocation looks good to them.
puts "YOU ARE RESPONSIBLE FOR USING THIS SCRIPT.  MAKE SURE YOUR RSYNC INVOCATION LOOKS GOOD."
set timeout -1
set answer n
while {[string compare $answer "n"] == 0} {
  puts "What is the source rsync file or path? (Use quotes with any whitespace)."
  set src_path [input_prompt "Source Path"]
  puts "What is the destination rsync file or path? (Use quotes with any whitespace)"
  set dest_path [input_prompt "Destination Path"]
  if {[string compare $username "root"] == 0} {
    set rsync_path "/opt/sfw/bin/rsync"
  } else {
    set rsync_path "rsync"
  }
  puts "Here is your rsync invocation:"
  puts "rsync -av --rsync-path=$rsync_path $src_path HOST:$dest_path"
  send_user "Does it look good? (y/n): "
  expect_user -re "(.*)\n"
  set response $expect_out(1,string)
  if {[string compare $response "y"] == 0} {
    if {[file exists $src_path]} {
      puts "$src_path exists..."
      set answer y
    } else {
      puts "$src_path does not exist..."
      set answer n
    }   
  } else {
    set answer n
  }
}

if {[catch {set hostlist [parse_list "hostlists/$hostlist"]} out]} {
  puts $out
} else {
  foreach host $hostlist {
    if {[regexp {^[^\#]} $host]} {
      if {[catch {rsync_host $username $src_path $dest_path $rsync_path $host $password} out]} {
        lappend error_buffer "# $host: $out"
        lappend error_buffer $host
        puts $out
      } else {
        puts "rsync completed to $host."
      }
    }
  }
  if {[catch {print_error_report $username "rsync_hosts.tcl" $error_buffer} out]} {
    puts $out
  } else {
    exit  
  }
}

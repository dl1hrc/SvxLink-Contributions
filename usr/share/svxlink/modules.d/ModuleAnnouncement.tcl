###############################################################################
#
# Announcement module implementation
#
###############################################################################

#
# This is the namespace in which all functions and variables below will exist.
# The name must match the configuration variable "NAME" in the
# [ModulePropagationMonitor] section in the configuration file. The name may
# be changed but it must be changed in both places.
#
namespace eval Announcement {

#
# Check if this module is loaded in the current logic core
#
if {![info exists CFG_ID]} {
  return;
}


#
# Extract the module name from the current namespace
#
set module_name [namespace tail [namespace current]];

#
# An "overloaded" playMsg that eliminates the need to write the module name
# as the first argument.
#
#   msg - The message to play
#
proc playMsg {msg} {
  variable module_name
  printInfo "Module name: $module_name $msg"
  ::playMsg $module_name $msg
}



#
# A convenience function for printing out information prefixed by the
# module name
#
proc printInfo {msg} {
  variable module_name;
  puts "$module_name: $msg";
}


#
# A convenience function for calling an event handler
#
proc processEvent {ev} {
  variable module_name
  ::processEvent "$module_name" "$ev"
}


#
# Executed when this module is being activated
#
proc activateInit {} {
  printInfo "Module activated"
}


#
# Executed when this module is being deactivated.
#
proc deactivateCleanup {} {
  printInfo "Module deactivated"
}


#
# Executed when a DTMF digit (0-9, A-F, *, #) is received
#
proc dtmfDigitReceived {char duration} {
  printInfo "DTMF digit $char received with duration $duration milliseconds";
}


#
# Executed when a DTMF command is received
#
proc dtmfCmdReceived {cmd} {
  #printInfo "DTMF command received: $cmd";
  if {$cmd == "0"} {
    processEvent "play_help"
  } elseif {$cmd == ""} {
    deactivateModule
  } else {
    processEvent "unknown_command $cmd"
  }
}


#
# Executed when a DTMF command is received in idle mode. That is, a command is
# received when this module has not been activated first.
#
proc dtmfCmdReceivedWhenIdle {cmd} {
  #printInfo "DTMF command received while idle: $cmd";
}


#
# Executed when the squelch open or close. If it's open is_open is set to 1,
# otherwise it's set to 0.
#
proc squelchOpen {is_open} {
  if {$is_open} {set str "OPEN"} else {set str "CLOSED"};
  printInfo "The squelch is $str";
}


#
# Executed when all announcement messages has been played.
# Note that this function also may be called even if it wasn't this module
# that initiated the message playing.
#
proc allMsgsWritten {} {
  #printInfo "all_msgs_written called...";
}


#
# Play an alert sound to get the users attention
#
proc playAlertSound {} {
  for {set i 0} {$i < 3} {set i [expr $i + 1]} {
    playTone 440 500 100
    playTone 880 500 100
    playTone 440 500 100
    playTone 880 500 100
    playSilence 600
  }
  playSilence 1000
  set alert 1
}


# check for Announcements alerts every minute
proc check_for_alerts {} {
  variable CFG_SPOOL_DIR
  variable CFG_CALL
  variable CFG_ALERT
  set playing 0
  set alert 0

  # move the *.info files
  foreach msg_file [glob -nocomplain -directory "$CFG_SPOOL_DIR/" $CFG_CALL.*.info ] {
    set target "$CFG_SPOOL_DIR/archive/[file tail $msg_file]"
    set wavfile [string trimright [file tail $msg_file] ".info"]

    if {$CFG_ALERT == 1 && $alert == 0} {
      playAlertSound
      set alert 1
    }

    playMsg $wavfile
    file rename -force "$msg_file" "$target"
    set playing 1
  }

  # move the *.wav files and play it
  if { $playing == 0 } {
    foreach msg_file [glob -nocomplain -directory "$CFG_SPOOL_DIR/" $CFG_CALL.*.wav ] {
      set target "$CFG_SPOOL_DIR/archive/[file tail $msg_file]"
      file rename -force "$msg_file" "$target"
    }
  }
}


# create archive directory if not exists
if {![file exists $CFG_SPOOL_DIR/archive]} {
  file mkdir $CFG_SPOOL_DIR/archive
}

append func $module_name "::check_for_alerts";
Logic::addMinuteTickSubscriber $func;


# end of namespace
}


#
# This file has not been truncated
#

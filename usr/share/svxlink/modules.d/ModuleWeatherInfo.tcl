###############################################################################
#
# WeatherInformation module event handlers
#
###############################################################################

#
# This is the namespace in which all functions and variables below will exist.
# The name must match the configuration variable "NAME" in the
# [ModuleTcl] section in the configuration file. The name may be changed
# but it must be changed in both places.
#
namespace eval WeatherInfo {


#
# Check if this module is loaded in the current logic core
#
if {![info exists CFG_ID]} {
  return
}


#
# Extract the module name from the current namespace
#
set module_name [namespace tail [namespace current]]


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
  variable module_name
}


#
# Executed when this module is being activated
#
proc activating_module {} {
  variable module_name
  Module::activating_module $module_name
}


#
# Executed when this module is being deactivated.
#
proc deactivating_module {} {
  variable module_name;
  Module::deactivating_module $module_name;
}


#
# Executed when the inactivity timeout for this module has expired.
#
proc timeout {} {
  variable module_name;
  Module::timeout $module_name;
}


#
# Executed when playing of the help message for this module has been requested.
#
proc play_help {} {
  variable module_name;
  Module::play_help $module_name;
}


#
# Executed when the state of this module should be reported on the radio
# channel. The rules for when this function is called are:
#
# When a module is active:
# * At manual identification the status_report function for the active module is
#   called.
# * At periodic identification no status_report function is called.
#
# When no module is active:
# * At both manual and periodic (long variant) identification the status_report
#   function is called for all modules.
#
proc status_report {} {
  #printInfo "status_report called...";
}


#
# Called when an illegal command has been entered
#
#   cmd - The received command
#
proc unknown_command {cmd} {
  playNumber $cmd
  playMsg "unknown_command"
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
}


#
# Ausgabe der Anzahl der aktuellen Wettermeldungen
#
proc getNumber {} {
  variable CFG_PLAY_DIR
  variable callsign
  variable msg_cnt
  variable files
  set callsign $Logic::CFG_CALLSIGN
  set files [glob -nocomplain -directory "$CFG_PLAY_DIR/archive/" $callsign.*.wav]
  set msg_cnt [llength $files]
  return $msg_cnt
}


#
# Executed when all announcement messages has been played.
# Note that this function also may be called even if it wasn't this module
# that initiated the message playing.
#
proc allMsgsWritten {} {
  #printInfo "all_msgs_written called...";
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


#
#
#
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


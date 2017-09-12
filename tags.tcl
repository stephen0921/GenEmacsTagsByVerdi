#-----------------------------------------------------------------------------
#                        N P I   M O D U L E   C B
#-----------------------------------------------------------------------------

# This call back is called when a module is found while traversing the
# hierarchy tree.  It creates a tag and adds the module definition name and the
# first instance of the module type to an array of items.  The list of items
# is used by the generic npi module call back to create tags for all other
# object types.

proc npiItemCb { object ref } {
  upvar $ref cbList

  # Brake down call back list into its parts.
  set LOG        [lindex $cbList 0]
  set level      [lindex $cbList 1]
  set itemsRef   [lindex $cbList 2]
  set identRef   [lindex $cbList 3]
  set indexRef   [lindex $cbList 4]

  upvar #$level $itemsRef items
  upvar #$level $identRef ident
  upvar #$level $indexRef index

  # Get the relevent information about the module.
  if { $object } {
    set npiType      [npi_get_str -property npiType      -object $object]
    set npiDefName   [npi_get_str -property npiDefName   -object $object]
    set npiDefFile   [npi_get_str -property npiDefFile   -object $object]
    set npiDefLineNo [npi_get     -property npiDefLineNo -object $object]
    set npiFullName  [npi_get_str -property npiFullName  -object $object]

    # Generate Raw information for debug.
#    puts $LOG "mod     $npiType\tnpiDefName='$npiDefName'\tnpiDefFile='$npiDefFile'\tnpiDefLineNo='$npiDefLineNo'\tnpiFullName='$npiFullName'"

    # If this type of module has not yet been seen, add it to the array of
    # items and save the particular instance found as the array entry's data.
    if {$npiDefName != ""} {
      if { ![info exists items($npiDefName)] } {
#        puts $LOG "modAdd($index)\n"
        set items($npiDefName) "$npiFullName"
        set ident($index) "$npiDefName\t$npiDefFile\t$npiDefLineNo"
        incr index
      }
    }
  }
}


#-----------------------------------------------------------------------------
#                              N P I   C B
#-----------------------------------------------------------------------------

proc npiCb { object ref } {
  upvar $ref cbList

  # Brake down call back list into its parts.
  set LOG        [lindex $cbList 0]
  set level      [lindex $cbList 1]
  set itemsRef   [lindex $cbList 2]
  set identRef   [lindex $cbList 3]
  set indexRef   [lindex $cbList 4]

  upvar #$level $itemsRef items
  upvar #$level $identRef ident
  upvar #$level $indexRef index

  # Get the relevent information about the module.
  if { $object } {
    set npiType        [npi_get_str -property npiType     -object     $object]
    set npiName        [npi_get_str -property npiName     -object     $object]
    set npiFileName    [npi_get_str -property npiFile     -object     $object]
    set npiLineNo      [npi_get     -property npiLineNo   -object     $object]

    # Get the scope name and type of the current object for comparison to list
    # of module instances.
	  set npiScopeHandle [npi_handle  -type     npiScope    -refHandle  $object]
    set scopeName      [npi_get_str -property npiFullName -object     $npiScopeHandle]
    set scopeType      [npi_get_str -property npiType     -object     $npiScopeHandle]

    # Generate Raw information for debug.
#    puts $LOG "obj     $npiType\tnpiName='$npiName'\tnpiFileName='$npiFileName'\tnpiLineNo='$npiLineNo'\tscopeName='$scopeName'\tscopeType='$scopeType'"

    # If the object is a package, class definition or program or contained
    # therein add the object to the tag list.
    if { $scopeType == "npiPackage"   ||
         $npiType   == "npiPackage"   ||
         $scopeType == "npiClassDefn" ||
         $npiType   == "npiClassDefn" ||
         $scopeType == "npiProgram"   || 
         $npiType   == "npiProgram" } {
#      puts $LOG "pkgAdd\n"
      set ident($index) "$npiName\t$npiFileName\t$npiLineNo"
      incr index

    # For all other objects only add a tag if 'the scope of the current object'
    # matches 'the recorded module instance' of 'one of items' in the array
    # of items that was generated when all module types were identified.
    } else {
      foreach { key data } [array get items] {
        if {$data == $scopeName} {
#          puts $LOG "objAdd\n"
          set ident($index) "$npiName\t$npiFileName\t$npiLineNo"
          incr index
        }
      }
    }
  }
}


#-----------------------------------------------------------------------------
# Main program
#-----------------------------------------------------------------------------

viaSetupL1Apps

  # Create the log file.
  set output_log "tags.log"
  set LOG [open $output_log "w"]
  set t [clock seconds]
  set format_str [clock format $t -format "%Y-%m-%d %H:%M:%S"]


  # Create an associative array of 'items'.
  array unset items
  array set items ""

  # Create an associative array of 'identifiers'.
  array unset ident
  array set ident ""

  # Index for the associative array containing identifiers.
  set index 0

  # Create data structure and a list of data structures to be sent to the call
  # back functions.  Append the data structures to the list.
  #
  set level [info level]
  set cbList ""
  lappend cbList $LOG
  lappend cbList $level
  lappend cbList "items"
  lappend cbList "ident"
  lappend cbList "index"


  # Bind the call back function 'npiItemCb' to all items of interest.  Then traverse the Verdi Knowledge
  # Database hierarchy tree to search for them.  Each of thems items can appear in the database multiple times.  'cbList' is received by the call back function
  # which will add the first instance of each item type to an array.  
  #
  ::npi_L1::npi_hier_tree_trv_register_cb "npiModule"    "npiItemCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiPackage"   "npiItemCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiProgram"   "npiItemCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiClassDefn" "npiItemCb" "cbList"
  ::npi_L1::npi_hier_tree_trv ""
  ::npi_L1::npi_hier_tree_trv_reset_cb


  # Bind all objects to be added to the tag list to the generic callback function
  # 'npiCb'.  This call back will add all tags for these objects.
  #
  ::npi_L1::npi_hier_tree_trv_register_cb "npiArrayNet"             "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiArrayTypespec"        "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiArrayVar"             "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiBitTypespec"          "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiBitVar"               "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiByteTypespec"         "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiByteVar"              "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiConstant"             "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiEnumNet"              "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiEnumTypespec"         "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiEnumVar"              "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiFuncCall"             "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiFunction"             "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiGenVar"               "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiGenScope"             "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiIODecl"               "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiIntTypespec"          "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiIntVar"               "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiIntegerTypespec"      "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiIntegerVar"           "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiInterface"            "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiInterfaceArray"       "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiLogicTypespec"        "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiLongIntTypespec"      "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiLongIntVar"           "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiModport"              "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiModuleArray"          "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiNet"                  "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiNetBit"               "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiPackage"              "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiPackedArrayNet"       "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiPackedArrayTypespec"  "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiPackedArrayVar"       "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiParameter"            "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiParameterBit"         "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiPort"                 "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiRealTypespec"         "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiRealVar"              "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiRefObj"               "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiReg"                  "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiRegBit"               "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiShortIntTypespec"     "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiShortIntVar"          "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiShortRealTypespec"    "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiShortRealVar"         "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiStringTypespec"       "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiStructNet"            "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiStructTypespec"       "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiStructVar"            "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiTask"                 "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiTaskCall"             "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiTypeParameter"        "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiTypePattern"          "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiTypespecMember"       "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiUnionTypespec"        "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiUnionVar"             "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiProgram"              "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiClassDefn"            "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiMethodFuncCall"       "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiClassTypespec"        "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiVirtualInterfaceVar"  "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiClassVar"             "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv_register_cb "npiClassObj"             "npiCb" "cbList"
  ::npi_L1::npi_hier_tree_trv ""
  ::npi_L1::npi_hier_tree_trv_reset_cb



  #
  # All identifiers have been captured and stored in the 'ident' associative array.
  # The next step is to extract the identifier information and write it out to the 
  # vi and emacs tag databases.
  #


  # Create an associative array that will hold the names of all source files.
  array unset files

  # Open the vi tag file. 
  set vtagFileName "tags"
  set vtagFilePtr [open $vtagFileName "w"]

  # Turn the associative array that contains all identifiers into a flattened
  # list of strings.
  # 
  # format of list:  <index> <identifier> <filename> <line number>
  set flat_ident [array get ident]

  # Sort the list by identifier.
  set sorted_ident [lsort -stride 2 -index 1 $flat_ident]

  # Write sorted list's data (no index) to tag file using vi formatting style.
  # While doing so, create an array of source file names to be used for
  # generating the emacs data base.
  #
  foreach {index tagInfo} $sorted_ident {
    puts $vtagFilePtr "$tagInfo"

    # Array of source file names
    set srcFile [lindex [split $tagInfo] 1]
    if { ![info exists files($srcFile)] } {
      set files($srcFile) "$srcFile"
    }
  }

  # Close vi tag file.
  close $vtagFilePtr


  # Open emacs tags file
  set etagFileName "TAGS"
  set etagFilePtr [open $etagFileName "w"]

  # To generate tagging information for all source files cycle through the
  # array of source file names.
  #
  foreach { fileName data } [array get files] {

    if { $fileName != ""} {
      # Open a source file.
      set srcFilePtr [open $fileName "r"]

      # Array used to store the byte count offset for each line in source file.
      array unset byteCounts
      array set byteCounts ""

      # emacs tag database format required byte offsets information for each
      # tag.
      set totalByteCount 0
      set lineCount      1
      set bytesThisLine [expr [gets $srcFilePtr str] + 1]

      # Calculate the byte offset for each line in source file.
      while { $bytesThisLine  >= 1 } {
        set byteCounts($lineCount) $totalByteCount
        set totalByteCount [expr $totalByteCount + $bytesThisLine] 
        set lineCount [expr $lineCount + 1]
        set bytesThisLine [expr [gets $srcFilePtr str] + 1]
      }
      close $srcFilePtr

      set entryList ""

      # Cycle through the list of sorted identifiers.  If the filename for an
      # identifier matches the current file, add the identifier and its line
      # offset to a string of identifiers for this file following the emacs
      # formatting style. 
      #
      foreach {index tagInfo} $sorted_ident {
        set srcFile [lindex [split $tagInfo] 1]
        if {$fileName == $srcFile} {
          set tag [lindex [split $tagInfo] 0]
          set line [lindex [split $tagInfo] 2]
          set offset $byteCounts($line)

	  #======= fix by yaohe begin ===========#
	    #set entry "\x7f$tag\x01,$offset"
	    set file_hdl [npi_text_file_by_name -name "$srcFile"]
	    set line_hdl [npi_text_line_by_number -ref $file_hdl -number $line]
	    set line_content [npi_text_property_str -type npiTextLineContent -ref $line_hdl]
	    regsub {\n$} $line_content {} line_content
	    set entry "$line_content\x7f$line,$offset"
	  #======= fix by yaohe end ===========#
	    
          append entryList "\n" $entry
        }
      }

      # Calculate the total length of the string that holds all the entries for
      # this file then write out the current file's tagging information to the
      # tag file following the emacs formatting style.
      #
      set entryListLength [string length $entryList]
      puts $etagFilePtr "\x0c\n$fileName,$entryListLength$entryList"
    }
  }

  # Close emacs tag file.
  close $etagFilePtr


  # Close log file.  End of Main Program
  close $LOG

  # End of Main Program
  #-----------------------------------------------------------------------------

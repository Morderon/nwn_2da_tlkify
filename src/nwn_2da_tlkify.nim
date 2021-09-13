import neverwinter/twoda, neverwinter/tlk, docopt, options, streams, json, parsecfg, os, parseutils, strutils, private/lang  #streams, options, json, parsecfg, re, os, strutils, typetraits

let doc = """
Update 2da and tlk files for NWN 1

Usage:
  nwn_2da_tlkify [options]

Options:
  -i TLK                      Input TLK file, Config key: tlk
  -s START                    Starting StrRef, Config key: start [default: highest]
  -o OUTTLK                   Output TLK file file, Config key: outtlk
  -d INDIR                    2da input directory, Config key: twoda
  -a OUTDIR                   2da output directory Config key: outtwoda
  -j JSONDIR                  Json Input directory, Config key: tlkjson
  -c CONFIG                   Configuration file [default: 2tconfig.ini]
  --auto-lower SEL            Turns on, off, or on for a specific 2da the automatically setting
                              the Lower field in classes or ConverNameLower field in racialtypes
                              Possible selections: all, off, class, and race.
                              Config key: autolower [default: all]
  --auto-plural PLU           Turns on, off, or on for a specific 2da the automatically setting
                              the Plural field in classes or NamePlural field in racialtypes
                              Possible selections: all, off, class, and race.
                              Config key: autoplural [default: all]
  --auto-adjective            Turns on auto setting of the ConverName from Name in racialtypes.
                              Config key: autoadjective true/false
  --auto-iprp_spells ISP      Sets the iprp_spells row to start autofill from the spells.2da.
                              Config key: autoiprp_spells [default: -1]
  --auto-spells SID           Sets the spells row to start autofill from feat.2da for Name and SpellDesc columns.
                              Config key: autospells [default: -1]
  --auto-iprp_feats FID       Sets the iprp_feats row to start autofill from feat.2da for the Name column.
                              Config key: autoiprp_feats [default: -1]
  --reserv-spells RID         Reserves space for spells.2da Name/SpellDesc columns so that any updates will always
                              take the same tlk strrefs.
                              Must be used with --start spells:xx or with startspells in a config file.
                              Only Name and SpellDesc will be sent to the spells start
                              Other spells.2da values will be sent to the default start (-s or start in config file)
                              A value of -1 keeps this value turned off.
                              A value <= 839 will turn it on for the whole 2da.
                              A value >839 will ignore any rows (padding) between 839 and the row ID (RID)
                              Config key: reservspells [default: -1]
  --start CSV                 Use if you want to set where individual 2das start, comma seperated.
                              Example: spells:50,classes:1000
                              Config key: start<2daname> without the <>
"""

let args = docopt(doc)


proc find(self: SingleTlk, str: string): int =
  result = -1
  for i in 0..self.highest():
    let entry = self[i.StrRef]
    if entry.isSome and entry.get().hasValue and $entry.get() == str:
      result = i
      break


var
 inputfile = $args["-i"]
 dict: Config
 outtlk = $args["-o"]
 injson = $args["-j"]
 intwoda = $args["-d"]
 outtwoda = $args["-a"]
 starts = $args["-s"]
 autol = $args["--auto-lower"]
 autop = $args["--auto-plural"]
 autoa = args["--auto-adjective"].to_Bool
 autoip = parseInt($args["--auto-iprp_spells"])
 autosp = parseInt($args["--auto-spells"])
 autoft = parseInt($args["--auto-iprp_feats"])
 rsvspl = parseInt($args["--reserv-spells"])
 start = initTable[string, int]()



let
  confl = $args["-c"]
  configExist = fileExists(confl)


if configExist:
  dict = loadConfig(confl)
  if outtlk == "nil":
    outtlk = dict.getSectionValue("General","outtlk", "nil")
  if injson == "nil":
    injson = dict.getSectionValue("General","tlkjson", "nil")
  if intwoda == "nil":
    intwoda = dict.getSectionValue("General","twoda", "nil")
  if outtwoda == "nil":
    outtwoda = dict.getSectionValue("General","outtwoda", "nil")
  if inputfile == "nil":
    inputfile = dict.getSectionValue("General","tlk", "nil")
  if starts == "highest":
    starts = dict.getSectionValue("General","start", "highest")
  if autol == "all":
    autol =  dict.getSectionValue("General","autolower", "all")
  if autop == "all":
    autop =  dict.getSectionValue("General","autoplural", "all")
  if not autoa:
    let auto = dict.getSectionValue("General","autoadjective", "false")
    if auto == "true":
        autoa = true
  if autoip == -1:
    autoip = parseInt(dict.getSectionValue("General","autoiprp_spells", "-1"))
  if autosp == -1:
    autosp = parseInt(dict.getSectionValue("General","autospells", "-1"))
  if autoft == -1:
    autoft = parseInt(dict.getSectionValue("General","autoiprp_feats", "-1"))
  if rsvspl == -1:
    rsvspl = parseInt(dict.getSectionValue("General","reservspells", "-1"))

start["default"] = -1 #initialize
if outtlk == "nil":
  quit("Error: No output defined for tlk.")
if injson == "nil":
  quit("Error: No input directory defined for json.")
if intwoda == "nil":
  quit("Error: No input directory defined for 2das.")
if outtwoda == "nil":
  quit("Error: No output directory defined for 2das.")

if (parseInt(starts, start["default"]) == 0 and starts != "highest"):
  quit("Error: tlk starting strref isn't a valid digit or highest")

var state: SingleTlk
if inputfile != "nil":
  if fileExists(inputfile):
    state  = openFileStream(inputfile).readSingleTlk()
  else:
    quit("Error: Tlk input file supplied but does not exist.")
else:
  starts = "" #initilize start here for new tlks
  state = newSingleTlk()

if starts == "highest":
  start["default"] = state.highest()+1

doAssert(start["default"] >= 0, "Error: Startting strref should not be negative.")

const tlkoffset = 16777216
var
  row: Row
  tblstream: Table[string, TwoDA]
  td_ipsp: seq[int]
  td_spellsn: seq[int]
  td_spellsd: seq[int]
  td_ipft: seq[int]


for i in split($args["--start"], ','):
  if i == "nil":
    break
  let csvi = split(i, ":")
  start[csvi[0]] = parseInt(csvi[1])


proc UpdateRAndTSpec(self: Row, colID: int, value: string, tlksr: int) =
  row[colID] = some($(tlksr+tlkoffset))
  state[tlksr.StrRef] = value

proc UpdateRAndT(self: Row, colID: int, value: string, startp: string) =
  let strref = state.find(value)
  if strref > -1:
    row[colID] = some($(strref+tlkoffset))
  else:
    UpdateRAndTSpec(row, colID, value, start[startp])
    start[startp] += 1

proc SafeAddToRow(self: TwoDA, row: Row, col: string, val: string, startp: string) =
   let colID = self.columns.find(col)
   if colID == -1:
     echo "Column name "&col&" not found"
   else:
     row.UpdateRAndT(colID, val, startp)

proc ResrvSpells(self: Row, colID: int, value: string, rowID: int, offset: int) =
  if rsvspl > -1:
    if rowID == 49:
      echo start["spells"]+rowID*2+offset
    if rsvspl <= 839 or rowID <= 839:
      row.UpdateRAndTSpec(colID, value, start["spells"]+rowID*2+offset)
    else:
      row.UpdateRAndTSpec(colID, value, start["spells"]+(840+rowID-rsvspl)*2+offset)


for file in walkFiles(injson&"*.json"):
  let filesplit = splitFile(file)
  if not fileExists(intwoda&filesplit.name&".2da"):
    echo "Json found for " & filesplit.name & " but no corresponding 2da."
  else:
    let twodas = openFileStream(intwoda&filesplit.name&".2da")
    let twoda = twodas.readTwoDA()
    twodas.close
    let json = parseFile(file)
    var startp: string
    if start.hasKey(filesplit.name):
      startp = filesplit.name
    else:
       if configExist:
        let startcs = dict.getSectionValue("General","start"&filesplit.name, "-1")
        if startcs != "-1":
          startp = filesplit.name
          start[filesplit.name] = parseInt(startcs)

       if not start.hasKey(filesplit.name):
         startp = "default"
    var
      spname: int
      spdesc: int
    if rsvspl > -1 and filesplit.name == "spells":
      if start.hasKey("spells"):
        spname = twoda.columns.find("Name")
        spdesc = twoda.columns.find("SpellDesc")
        startp = "default" #redirect all non-name/spelldesc to default
      else:
        rsvspl = -1
    for itm in items(json):

      if itm.hasKey("id"):
        let rowID = itm["id"].getInt()
        row = twoda[rowID].get()
        if filesplit.name == "iprp_spells" and autoip != -1 and rowID >= autoip and itm.hasKey("Name"):
          td_ipsp.add(rowID)
        elif filesplit.name == "spells":
          if itm.hasKey("Name"):
            if autosp != -1 and rowID >= autosp:
              td_spellsn.add(rowID)
            row.ResrvSpells(spname, itm["Name"].getStr(), rowID, 0)
          if itm.hasKey("SpellDesc"):
            row.ResrvSpells(spdesc, itm["SpellDesc"].getStr(), rowID, 1)
            if autosp != -1 and rowID >= autosp:
              td_spellsd.add(rowID)
        elif filesplit.name == "iprp_feats" and autoft != -1 and rowID >= autoft and itm.hasKey("Name"):
          td_ipft.add(rowID)

        for p in pairs(itm):
          if $p.key == "id" or (rsvspl > -1 and filesplit.name == "spells" and ($p.key == "Name" or $p.key == "SpellDesc")):
            continue
          var colID = twoda.columns.find($p.key)
          if colID == -1:
            echo "Column name " & $p.key & " not found in " & filesplit.name
            continue


          row.UpdateRAndT(colID, p.val.getStr(), startp)


        if filesplit.name == "racialtypes":
          if (autol == "all" or autol == "race") and not itm.hasKey("ConverNameLower"):
            if itm.hasKey("ConverName"):
              SafeAddToRow(twoda, row, "ConverNameLower", itm["ConverName"].getStr().toLowerAscii, startp)
            elif autoa and itm.hasKey("Name"):
              SafeAddToRow(twoda, row, "ConverNameLower", itm["Name"].getStr().toadjective().toLowerAscii, startp)
          if (autop == "all" or autop == "race") and itm.hasKey("Name") and not itm.hasKey("NamePlural"):
            SafeAddToRow(twoda, row, "NamePlural", itm["Name"].getStr().plural(), startp)
          if autoa and itm.hasKey("Name") and not itm.hasKey("ConverName"):
            SafeAddToRow(twoda, row, "ConverName", itm["Name"].getStr().toadjective(), startp)
        elif filesplit.name == "classes":
          if itm.hasKey("Name"):
            if (autol == "all" or autol == "class") and not itm.hasKey("Lower"):
              SafeAddToRow(twoda, row, "Lower", itm["Name"].getStr().toLowerAscii, startp)
            if (autop == "all" or autop == "class") and not itm.hasKey("Plural"):
              SafeAddToRow(twoda, row, "Plural", itm["Name"].getStr().plural(), startp)

        twoda[rowID]=row

      else:
        echo "This does not have a valid id."

    tblstream[filesplit.name] = twoda

proc getTwoDA(name: string): TwoDA =
  if tblstream.hasKey(name):
    result = tblstream[name]
  elif fileExists(intwoda&name&".2da"):
    let tmps = openFileStream(intwoda&name&".2da")
    result = tmps.readTwoDA()
    tmps.close


if tblstream.hasKey("feat"):
  if autoft > -1:
    var updtwoda = getTwoDA("iprp_feats")
    let
      colID = updtwoda.columns.find("Name")
      colFeat = updtwoda.columns.find("FeatIndex")
      ftName = tblstream["feat"].columns.find("FEAT")

    if not isNil(updtwoda):
      for i in autoft..updtwoda.high:
        if not td_ipft.contains(i):
          row = updtwoda[i].get()
          if row[colFeat].isSome:
            let featidx = parseInt(row[colFeat].get())
            if tblstream["feat"][featidx].isSome:
                row[colID] = tblstream["feat"][featidx].get()[ftName]
                updtwoda[i] = row

      tblstream["iprp_feats"] = updtwoda

  if autosp > -1:
    var updtwoda = getTwoDA("spells")

    let
      colID = updtwoda.columns.find("Name")
      colSpell = updtwoda.columns.find("SpellDesc")
      colFeat = updtwoda.columns.find("FeatID")
      ftName = tblstream["feat"].columns.find("FEAT")
      ftDesc = tblstream["feat"].columns.find("DESCRIPTION")
    if not isNil(updtwoda):
      for i in autosp..updtwoda.high:
        if not td_spellsn.contains(i) or not td_spellsd.contains(i):
          row = updtwoda[i].get()
          if row[colFeat].isSome:
            let featidx = parseInt(row[colFeat].get())
            if tblstream["feat"][featidx].isSome:
              if not td_spellsn.contains(i):
                row[colID] = tblstream["feat"][featidx].get()[ftName]
              if not td_spellsd.contains(i):
                row[colSpell] = tblstream["feat"][featidx].get()[ftDesc]
          updtwoda[i] = row

      tblstream["spells"] = updtwoda

if autoip > -1 and tblstream.hasKey("spells"):
  var updtwoda = getTwoDA("iprp_spells")

  let colID = updtwoda.columns.find("Name")
  let colSpell = updtwoda.columns.find("SpellIndex")
  let spName = tblstream["spells"].columns.find("Name")
  if not isNil(updtwoda):
    for i in autoip..updtwoda.high:
      if not td_ipsp.contains(i):
        row = updtwoda[i].get()
        if row[colSpell].isSome:
          let spellidx = parseInt(row[colSpell].get())
          if tblstream["spells"][spellidx].isSome:
            row[colID] = tblstream["spells"][spellidx].get()[spName]
            updtwoda[i] = row

    tblstream["iprp_spells"] = updtwoda

for k, v in tblstream.pairs:
  let outda = newFileStream(outtwoda&k&".2da", fmWrite)
  outda.writeTwoDA(v)
  outda.close

let output = openFileStream(outtlk, fmWrite)

output.writeTlk(state)

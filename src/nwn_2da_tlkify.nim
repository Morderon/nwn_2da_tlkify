import neverwinter/twoda, neverwinter/tlk, docopt, options, streams, json, parsecfg, os, parseutils, strutils  #streams, options, json, parsecfg, re, os, strutils, typetraits

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
  --auto-lower-off            Turns off converting ConverName in racialtypes to lower case
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
 start: int


let
  confl = $args["-c"]
  configExist = fileExists(confl)
  autol = args["--auto-lower-off"]
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

if outtlk == "nil":
  quit("Error: No output defined for tlk.")
if injson == "nil":
  quit("Error: No input directory defined for json.")
if intwoda == "nil":
  quit("Error: No input directory defined for 2das.")
if outtwoda == "nil":
  quit("Error: No output directory defined for 2das.")
if (parseInt(starts, start) == 0 and starts != "highest"):
  quit("Error: tlk starting strref isn't a valid digit or highest")

doAssert(start >= 0, "Error: Startting strref should not be negative.")

var state: SingleTlk

if inputfile != "nil":
  if fileExists(inputfile):
    state  = openFileStream(inputfile).readSingleTlk()
  else:
    quit("Error: Tlk input file supplied but does not exist.")
else:
  starts = "" #initilize start here for new tlks
  start = 0
  state = newSingleTlk()

const tlkoffset = 16777216
var row: Row

proc UpdateRAndT(self: Row, colID: int, value: string) =
  let strref = state.find(value)
  if strref > -1:
    row[colID] = some($(strref+tlkoffset))
  else:
    row[colID] = some($(start+tlkoffset))
    state[start.StrRef] = value
    start += 1

if starts == "highest":
  start = state.highest()+1

for file in walkFiles(injson&"*.json"):
  let filesplit = splitFile(file)
  if not fileExists(intwoda&filesplit.name&".2da"):
    echo "Json found for " & filesplit.name & " but no corresponding 2da."
  else:
    let twoda = openFileStream(intwoda&filesplit.name&".2da").readTwoDA()
    let json = parseFile(file)
    for itm in items(json):
      if itm.hasKey("id"):
        let rowID = itm["id"].getInt()
        row = twoda[rowID].get()
        for p in pairs(itm):
          if $p.key == "id":
            continue
          var colID = twoda.columns.find($p.key)
          if colID == -1:
            echo "Column name " & $p.key & " not found in " & filesplit.name
            continue

          row.UpdateRAndT(colID, p.val.getStr())

          if not autol and filesplit.name == "racialtypes" and $p.key == "ConverName" and not itm.hasKey("ConverNameLower"):
            colID = twoda.columns.find("ConverNameLower")
            if colID == -1:
              echo "Column name ConverNameLower not found in racialtypes"
            else:
              row.UpdateRAndT(colID, itm["ConverName"].getStr().toLowerAscii)

          twoda[rowID]=row

      else:
        echo "This does not have a valid id."

      let outda = newFileStream(outtwoda&filesplit.name&".2da", fmWrite)
      outda.writeTwoDA(twoda)

let output = openFileStream(outtlk, fmWrite)

output.writeTlk(state)

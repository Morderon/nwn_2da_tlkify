import neverwinter/twoda, neverwinter/tlk, neverwinter/gff, docopt, options, streams, json, os, strutils, tables, parsecfg

let tlkstart = 16777216.StrRef
let doc = """
Create scrolls

Usage:
  nwn_2da_tlkify [options]

Options:
  -i 2DADIR                   2da DIR. This directory should contain spells.2da, classes.2da, iprp_spells.2da and des_crft_scroll.2da.
                              Config key: indir
  -j SPELL                    The path of the file spells.json. Config Key: spellsjson
  -o OUTDIR                   Output directory. Config key: outdir
  -m                          Manages des_crft_scroll.2da Will add the necessary columns/rows and fill it out.
                              Config Key: managecrft true/false
  -t TLK                      Use tlk values instead of tlk reference. Should contain the path to a tlk file. Config Key: tlkpath
  -c CONFIG                   Path to config file. [default: scrollmake.ini]
  -p PRE                      The prefix if there's no current scroll resref. Config key: prefix [default: tc_scr_]

 """

let args = docopt(doc)

proc newProperty(self: var GffList, entry: int) =
  self.add(newGffStruct(0))
  self[entry]["ChanceToAppear", GffByte] = 100

proc classRest(self: var GffList, class: GffWord) =
  self.newProperty(self.len)
  let l = self.len-1
  self[l]["CostTable", GffByte] = 0
  self[l]["CostValue", GffWord] = 0
  self[l]["Param1", GffByte] = 255
  self[l]["Param1Value", GffByte] = 0
  self[l]["PropertyName", GffWord] = 63
  self[l]["Subtype", GffWord] = class

proc scrollTemplate(): GffRoot =

  # "create result template"
  result = newGffRoot("UTI ")

  result["AddCost", GffDWord] = 0
  result["BaseItem", GffInt] = 75
  result["Charges", GffByte] = 0
  result["Comment", GffCExoString] = ""
  result["Cost", GffDWord] = 0
  result["DescIdentified", GffCexoLocString] = newCExoLocString()
  result["Description", GffCexoLocString] = newCExoLocString()
  result["Identified", GffByte] = 1
  result["LocalizedName", GffCexoLocString] = newCExoLocString()
  result["ModelPart1", GffByte] = 0
  result["PaletteID", GffByte] = 26
  result["Plot", GffByte] = 0
  result["Plot", GffByte] = 0
  result["Stolen", GffByte] = 0
  result["StackSize", GffWord] = 1
  result["PropertiesList", GffList] = newGffList()

  #no idea why i need to put this into a var, but it makes the compiler happy
  var props = result["PropertiesList", GffList]
  props.newProperty(0)
  # especially when i just... reassigned it here no problem
  result["PropertiesList", GffList] = props
  result["PropertiesList", GffList][0]["CostTable", GffByte] = 3
  result["PropertiesList", GffList][0]["CostValue", GffWord] = 1
  result["PropertiesList", GffList][0]["Param1", GffByte] = 255
  result["PropertiesList", GffList][0]["Param1Value", GffByte] = 0
  result["PropertiesList", GffList][0]["PropertyName", GffWord] = 15

proc isValid(cell: Cell): bool =
  if cell.isSome:
    result = true


let configf = $args["-c"]

var
 dir = $args["-i"]
 outdir = $args["-o"]
 tlkf = $args["-t"]
 mancr = args["-m"].to_bool()
 spjsonf = $args["-j"]
 dict: Config
 prefix =  $args["-p"]

 
if fileExists(configf):
  dict = loadConfig(configf)
  if dir == "nil":
    dir = dict.getSectionValue("Scrollmake","indir", "nil")
  if outdir == "nil":
    outdir = dict.getSectionValue("Scrollmake","outdir", "nil")
  if spjsonf == "nil":
    spjsonf = dict.getSectionValue("Scrollmake","spellsjson", "nil")
  if not mancr:
    let val = dict.getSectionValue("Scrollmake","managecrft", "false")
    if val == "true":
      mancr = true
  if tlkf == "nil":
    tlkf = dict.getSectionValue("Scrollmake","tlkpath", "nil")
  if prefix == "tc_scr_":
    prefix = dict.getSectionValue("Scrollmake","prefix", "tc_scr_")  
    

if outdir == "nil":
  quit("No output directory specified.")
  
let
  classf = dir&"classes.2da"
  crftscf = dir&"des_crft_scroll.2da"
  spellf = dir&"spells.2da"
  ispellf = dir&"iprp_spells.2da"

if not fileExists(classf):
  quit("classes.2da missing")
elif not fileExists(crftscf):
  quit ("des_crft_scroll.2da missing")
elif not fileExists(spellf):
  quit ("spells.2da missing")
elif not fileExists(ispellf):
  quit ("iprp_spells.2da missing")
elif tlkf != "nil" and not fileExists(tlkf):
  quit("Tlk file missing. Note: This is optional, if you do not want to use a tlk table don't specify a tlk file.")
elif spjsonf != "nil" and not fileExists(spjsonf):
  quit("Spells.json file missing. Note: This is optional, if you do not want to use a spells.json do not specify a spells.json file.")


var
  tlkr: SingleTlk

if tlkf != "nil":
  tlkr = openFileStream(tlkf).readSingleTlk()


# Stage one: load classes
let
  classs = openFileStream(classf)
  class = classs.readTwoDA()
  classc = class.columns.find("SpellTableColumn")
classs.close

 # get class spell tables
var classes = initTable[string, seq[int]]()

for i in 0..class.high:
  let c = class[i].get()[classc]
  if isValid(c):
    discard classes.hasKeyOrPut(c.get(), @[])
    classes[c.get()].add(i)


var scrollc: seq[int]



let crftscrs = openFileStream(crftscf)
let crftscr = crftscrs.readTwoDA()
crftscrs.close


# add classes to des_crft_scroll
for i in classes.keys:
  let col =crftscr.columns.find(i)
  if col > -1:
    scrollc.add(col)  
  elif mancr:
    var seq = crftscr.columns
    seq.add(i)
    crftscr.columns = seq
    for n in 0..crftscr.high:
      var row = crftscr[n].get()
      row.add(crftscr.default)
      crftscr[n] = row


proc getResRef(id: int): string =
  let row = crftscr[id]
  let rowg = row.get()
  for i in scrollc:
    let c = rowg[i]
    if isValid(c) and c.get() != "*****":
      result = toLowerAscii(c.get())
      break


let
  spells = openFileStream(spellf)
  spell = spells.readTwoDA()
spells.close

let
  ips = openFileStream(ispellf)
  ip = ips.readTwoDA()
ips.close




let
 labelc = spell.columns.find("Label")
 namec = spell.columns.find("Name")
 innatec = spell.columns.find("Innate")
 descc = spell.columns.find("SpellDesc")
 ipi = ip.columns.find("SpellIndex")


var
  domaint = initTable[int, bool]()
  ipt = initTable[int, int]()
# load in if domain spell and custom item property from row
if fileExists(spjsonf):

  let json = parseFile(spjsonf)
  for obj in items(json):
    let s = obj.hasKey("scroll")
    let d = obj.hasKey("domain")
    if s or d:
      let id = obj["id"].getInt()
      if s:
        ipt[id] = obj["scroll"].getInt()
      if d:
        domaint[id] = obj["domain"].getBool()

for i in 0..spell.high:
  let
    row = spell[i].get()
    label = row[labelc]
    name = row[namec]
    innate = row[innatec]
    desc = row[descc]
  var
    doonce = false
    scroll: GffRoot
    resref: string
    crrow: Row

  if isValid(label) and isValid(name) and isValid(innate) and isValid(desc):
    for k in classes.keys:
      let c = spell.columns.find(k)
      if c > -1 and isValid(row[c]):
        #get the ip, name, and desc
        if not doonce:
          var ipn = -1
          if ipt.hasKey(i):
            ipn = ipt[i]
          else:
            #get the first ip
            for p in 0..ip.high:
              let ipc = ip[p].get()[ipi]
              if isValid(ipc) and ipc.get() == $i:
                ipn = p
                break
            if ipn == -1:
              echo "No item property for spell: " & $i
              break
          # get the resref, also if managing des_crft_scroll create the whole row or modify it
          if crftscr[i].isSome:
            if mancr:
              crrow = crftscr[i].get()
            resref = getResRef(i)
            if resref == "":
              resref = prefix & $i
          else:
           resref = prefix & $i
           if mancr:
             crrow.add(label)
             for x in 1..<crftscr.columns.len:
               crrow.add(crftscr.default)

          doonce = true
          # actually generate the scroll here
          scroll = scrollTemplate()
          let descval = parseInt(desc.get()).StrRef
          let nameval = parseInt(name.get()).StrRef
          if tlkf != "nil" and descval >= tlkstart:
            scroll["DescIdentified", GffCexoLocString].entries[0] = $tlkr[descval-tlkstart].get()
          else:
            scroll["DescIdentified", GffCexoLocString].strRef = descval
          if tlkf != "nil" and nameval >= tlkstart:
            scroll["LocalizedName", GffCexoLocString].entries[0] = $tlkr[nameval-tlkstart].get()
          else:
            scroll["LocalizedName", GffCexoLocString].strRef = nameval

          scroll["PropertiesList", GffList][0]["Subtype", GffWord] = ipn.GffWord

          scroll["Tag", GffCExoString] = toUpperAscii(resref)
          scroll["TemplateResRef", GffResRef] = resref.GffResRef

          if domaint.hasKey(i) and domaint[i]:
            var cleric = scroll["PropertiesList", GffList]
            cleric.classRest(2)
            scroll["PropertiesList", GffList] = cleric
        # end get the ip, name, and desc
        #add classe use restrictions here, except on scrolls that don't accept use restrictions
        if not (i == 70 or i == 97 or i == 152 or i == 142 or i == 153 or  i == 147 or i == 126):
          var props = scroll["PropertiesList", GffList]
          for class in classes[k]:
            props.classRest(class.GffWord)
          scroll["PropertiesList", GffList] = props
        if mancr:
          crrow[crftscr.columns.find(k)] = some(resref)
    #generated a scroll lets add the necessary row(s) to the 2da
    if doonce and mancr:
      if i > crftscr.high:
        for h in crftscr.high+1..i:
          var newRow: Row
          # we have to assign the columns too
          for x in 0..<crftscr.columns.len:
            newRow.add(crftscr.default)
          crftscr[h] = newRow
      #now we add the row we created for our scroll
      crftscr[i] = crrow



    # output
    if not isNil(scroll):
      let item = openFileStream(outdir&resref&".uti", fmWrite)
      item.write(scroll)
      item.close

if mancr:
  let crftos = openFileStream(outdir&"des_crft_scroll.2da", fmWrite)
  crftos.writeTwoDA(crftscr)
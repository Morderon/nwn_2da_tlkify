# nwn_2da_tlkify

A tool to assemble 2das/tlks from a collection of json files.


##Configure operation in one of two ways:

1) Command line (has preference)

```
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
  --reserv-spells RID         Reserves space for spells.2da Name/SpellDesc columns so that any updates will                                     always take the same tlk strrefs.
                              Must be used with --start spells:xx or with startspells in a config file.
                              Only Name and SpellDesc will be sent to the spells start
                              Other spells.2da values will be sent to the default start (-s or start in config                               file)
                              A value of -1 keeps this value turned off.
                              A value <= 839 will turn it on for the whole 2da.
                              A value >839 will ignore any rows (padding) between 839 and the row ID (RID)
                              Config key: reservspells [default: -1]
  --start CSV                 Use if you want to set where individual 2das start, comma seperated.
                              Example: spells:50,classes:1000
                              Config key: start<2daname> without the <>
```

Example:

nwn_2da_tlkify -o test.tlk -d ./2da/ -a ./o2da/ -j ./json/

Will create a tlk file by the name of test in the working directory, source the 2das from 2da folder, source the json from the json folder, and output the new 2das to the o2da folder.

2) Use a config file

Sample config file, default name 2tconfig.ini
```
[General]
tlk="./Tlk input/original.tlk" # input tlk file
outtlk="test.tlk" # new tlk file
twoda="./Input 2das/" # directory for the original/input 2das
tlkjson="./Input json/" # directory for the description jsons, should be named after 2da name.json
outtwoda="./Output 2das/" # directory for output twodas
start=50 # where the tlk row additions start
```

## Json format

The name of the 2da should match the name of the json.

Each json node needs an "id" element which matches the row number within the 2da

All other elements names should match the column names of the 2da, this is case sensitive.

Example json:

```
[
	{
		"id": 1,
		"Description": "domain 1"
	},
	{
		"id": 4,
		"Description": "domain 4"
	},
	{
		"id": 6,
		"Description": "domain 6",
		"Name": "domain name"
	}
]
```

The above will change the "Description" column of a 2da for 2da rows 1, 4, and 6 and change the Name column of row 6. If the value isn't already within the tlk it will be added.

## Notes:

A starting strref of highest will append everything to the end of the tlk.

This program doesn't currently care if a strref has a value or not and will overwrite the current value.

Feel free to supply the same value multiple times, the program will only put one instance into the tlk file.

Automated options:
  --auto-plural When on fills out the Plural Columns within classes and racialtypes.2da from the Name field, the function that determines how to plural is rather basic
  --auto-adjective When on fills out ConverName field in racialtpes.2da from Name field. Basically if it ends with f, f->ven.
  --auto-iprp_spells Fills out the Name field in iprp_spells from spells.2da
  --auto-spells Fills out Name/SpellDesc from feats.2da
  --auto-iprp_feats Fills out Name from feats.2da

Automated options will function if enabled and if a value is NOT explicitly defined:

```
{
  "Name":"Orc"
},
{
  "Name":"Drow",
  "NamePlural":"Drow"
}
```

The above json will generate a Name value of Orc and NamePlural will automatically be filled with Orcs. Another Name field will be filled with "Drow" and the NamePlural field will also be "Drow"; if left to be auto filled it would had been "Drows"


## Known issues:

SpellDesc and Name field from spells.2da isn't fully supported. Depending on how you use this tool, the tlk strrefs may change from one use to the next which will cause scroll items to have the wrong description.

This can be avoided by using the --reserv-spells option.
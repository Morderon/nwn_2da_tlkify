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

```[
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
]```

The above will change the "Description" column of a 2da for 2da rows 1, 4, and 6 and change the Name column of row 6. If the value isn't already within the tlk it will be added.

## Notes:

A starting strref of highest will append everything to the end of the tlk.
This program doesn't currently care if a strref has a value or not and will overwrite the current value.
Feel free to supply the same value multiple times, the program will only put one instance into the tlk file.
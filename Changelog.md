* New in 0.1.2
  New automated options:
    --auto-plural When on fills out the Plural Columns within classes and racialtypes.2da from the Name field, the function that determines how to plural is rather basic
    --auto-adjective When on fills out ConverName field in racialtpes.2da from Name field. Basically if it ends with f, f->ven.
    --auto-iprp_spells Fills out the Name field in iprp_spells from spells.2da
    --auto-spells Fills out Name/SpellDesc from feats.2da
    --auto-iprp_feats Fills out Name from feats.2da

  --start Ability to define where each 2da's string ref starts within a tlk table.

  --reserv-spells When enabled will ensure that spells.2da Name/SpellDesc columns are always placed within the same StrRef

* New in 0.1.1

  ConverName is automatically converted to lower case for ConverNameLower in racialtypes.2da
  Name is automatically converted to lower case for Lower in classes.2da
  These options can be turned off with the new --auto-lower paramater. If a value is provided in the json for the lower case column it will continue to be used instead.
  File streams are now closed
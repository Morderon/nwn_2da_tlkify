
proc plural*(s: string): string =
    let last = s[^1]
    let twolast = s[^2..^1]
    #if twolast == "us":
    #  result = s[0..^3]&"i"
    if twolast == "is":
      result = s[0..^3]&"es"
    elif last == 's' or last == 'x' or last == 'z' or twolast == "ch" or twolast == "sh":
      result = s & "es"
    elif last == 'f':
      result = s[0..^2]&"ves"
    elif twolast == "fe":
      result = s[0..^3]&"ves"
    elif last == 'y':
      let tolast = s[^2]
      if tolast == 'a' or tolast == 'e' or tolast == 'i' or tolast == 'o' or tolast == 'u' or tolast == 'y':
        result = s&"s"
      else:  
        result = s[0..^2]&"ies"
    #elif twolast == "on":
      #result = s[0..^3]&"a"
    else:
      result = s&"s"

proc toadjective*(s: string): string =
    let last = s[^1]
    result = s
    if last == 'f':
      result = s[0..^2]&"ven"
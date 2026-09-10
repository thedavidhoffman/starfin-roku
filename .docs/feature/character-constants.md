# Character Constants

`source/Char.bs` provides named character constants:

| Constant | Character code | Meaning |
| --- | --- | --- |
| `Char.Null` | 0 | Null character |
| `Char.Tab` | 9 | Horizontal tab |
| `Char.NewLine` | 10 | Line feed |
| `Char.CarriageReturn` | 13 | Carriage return |
| `Char.DoubleQuote` | 34 | Double quotation mark |

Import the file to use the constants:

```brightscript
import "pkg:/source/Char.bs"

quotedTitle = Char.DoubleQuote + title + Char.DoubleQuote
```

`Char.NewLine` is a line feed only. Code that needs a carriage return followed by
a line feed must use `Char.CarriageReturn + Char.NewLine` to preserve both
characters.

//------------------------------------------------------------------------------
//
// General functions that not is part of an object
//
// Cre 2004-02-17 Pma
//
//------------------------------------------------------------------------------
unit GenUtils;

interface

uses
  SysUtils,     // String conversions
  Types,        // TPoint
  Graphics,     // TCanvas
  Math,         // Mathematics
  FileCtrl,     // File utilities
  StrUtils;     // Ansi String

  //--- String routines --------------------------------------------------------

  function StringAddDel (iStr : string; iDel : char): string;
  function StringNxtDel (var index: integer; iStr : string; iDel : char): string;
  function ExtractFileNamePart (iName : string): string;
  function ExtractParentDir (iDir : string): string;
  function StringToInt (iStr : string): integer;

implementation

//------------------------------------------------------------------------------
//                              Text procedures
//------------------------------------------------------------------------------
// Add duoble delimiter if it exist in the string
//
function StringAddDel (iStr : string; iDel : char): string;
var
  i : integer;
  sTmp : string;
begin
  sTmp := '';

  for i := 1 to length(iStr) do
    if iStr[i] = iDel then
      sTmp := sTmp + iDel + iDel
    else
      sTmp := sTmp + iStr[i];
  StringAddDel := sTmp;
end;
//------------------------------------------------------------------------------
// Get next string (from index) up to next delimiter (iDel) (skipp id double)
//
function StringNxtDel (var index: integer; iStr : string; iDel : char): string;
var
  stop : boolean;
  sTmp : string;
begin
  sTmp := '';
  stop := false;

  // Walk string until end or a stop is called for

  while (not stop) and (index <= length(iStr)) do
    begin

      // Test if this is a delimiter character

      if (iStr[index] = iDel) then
        begin

          // if not next char also is a delimiter then stop

          if (iStr[index + 1] <> iDel) then
            stop := true
          else
            begin
              // add this delimiter and jump one char

              sTmp := sTmp + iDel;
              index := index + 1;
            end
        end
      else
        begin

          // It was not a delimiter, add this character

          sTmp := sTmp + iStr[index];
        end;

      // increment one index

      index := index + 1;
    end;

  StringNxtDel := sTmp;
end;
//------------------------------------------------------------------------------
// Extract the file name part (without extent or path)
//
function ExtractFileNamePart (iName : string): string;
var
  i : integer;
  sTmp : string;
begin
  ExtractFileNamePart := '';

  sTmp := ExtractFileName(iName);

  for i := length(sTmp) downto 1 do
    if sTmp[i] = '.' then
      begin
        ExtractFileNamePart := AnsiLeftStr(sTmp,i-1);
        exit;
      end;
end;
//------------------------------------------------------------------------------
// Find the Parent directory (last char is \)
//
function ExtractParentDir (iDir : string): string;
var
  i : integer;
  sTmp : string;
begin
  ExtractParentDir := '';

  sTmp := ExcludeTrailingPathDelimiter (iDir);

  for i := length(sTmp) downto 1 do
    if sTmp[i] = '\' then
      begin
        ExtractParentDir := AnsiLeftStr(sTmp,i);
        exit;
      end;
end;
//------------------------------------------------------------------------------
// Convert string to integer
//
function StringToInt (iStr : string): integer;
var
  i : integer;
  s : string;
begin
  s := '';

  for i := 1 to length(iStr) do
    if (iStr[i] >= '0') and (iStr[i] <= '9') then
      s := s + iStr[i];

  if length(s) > 0 then
    StringToInt := StrToInt(s)
  else
    StringToInt := -1;
end;
end.

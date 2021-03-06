//------------------------------------------------------------------------------
//
// Map data objcect that handles all Map Items in the Map
//
// Cre 2004-02-17 Pma
//
//------------------------------------------------------------------------------
unit MapItemList;

interface

uses
  SysUtils, // String conversions used
  Types,    // TPoint
  Classes,  // TList
  Graphics, // TCanvas
  StrUtils, // Ansi strings
  Forms,    // Application
  Math,     // Mathematics

  GenUtils, // General utilities (mine)
  MapItem,
  MapItemType,
  MapItemTypeList,
  LeafUnit, // Save/Loading
  GeomUtils;    // Geometrical utilities

const
    // Save/Load

  LeafItem             = 0;

  MapItemExt = '.txt';     // File Extent for map item data
  MapUndoListMaxLen = 10; // Max number of undos

type

  TMapItemUndoType = (
    udNewItem,    // New Item inserted, remember item
    udPasteItem,  // New Item Pasted in, remember item
    udDelItem,    // Item deleted, remember item (and store it)
    udSetType,    // New type set, remember iten (and store it)
    udMoveItem,   // Item Moved, remember distance
    udMoveMid,    // Item moved, remember distance
    udScaleItem,  // Item scaled, remember scale
    udRotateItem, // Item rotated, remember angle
    udEditName,   // Name changed, remember name
    udEditDesc,   // Description changed, remember description
    udMovePnt,    // Point moved, remember point and index
    udNewPnt,     // New point inserted, remember index
    udDelPnt,     // Point deleted, remember point and index
    udNone);       // Nothing done

  TMapItemUndo = record
    UndoType    : TMapItemUndoType; // The undo type
    UndoItem    : TMapItem;         // Pointer to Item changed
    UndoItemOld : TMapItem;         // Pointer to copied Item changed
    UndoString  : string;           // String  variable for things
    UndoPoint   : TPoint;           // point   variable for things
    UndoReal    : real;             // real    variable for things
    UndoIndex   : integer;          // integer variable for things
  end;

  // The base class for a set of Map Points

  TMapItemList = class(TList)
  private
    MapUndoList       : Array [1..MapUndoListMaxLen] of TMapItemUndo;
    MapUndoListLen    : integer; // Current undo pint
    MapUndoMaxReached : boolean; // Undo has reach its limit
    MapUndoLenAtSave  : integer; // Undo pint at last save
  public

    //--- Constructors and destructors -----------------------------------------

    constructor Create; // Create an object

    // Save all items in a map

    function  SaveToFile   (var F : TextFIle) : boolean;

    // Load all items in a Map

    function  LoadFromFile (var F : TextFile;
                            pMitl : TMapItemTypeList) : boolean;

    // Return if any Map Item has changed

    function  InqDirty : boolean;

    // Clear all Map items

    procedure Clear; override ;

    //--------------------- Read only functions --------------------------------

    // Inq number of Map Points in current Map

    function InqPoints : integer;

    // Return a Map Point using different search criteria

    function InqPoint(pMap : TPoint) :TMapItem;overload; // At a Map point
    function InqPoint(index: integer):TMapItem;overload; // At index
    function InqPoint(sName: string) :TMapItem;overload; // With a name

    // Find out if a point is visible

    function InqPointIsVisible (mp : TMapItem) : boolean;

    function GetUniqueName (sName : string) : string;

    //------------------- Change Item and Undo functions -----------------------

    procedure ItemNew (mp : TMapItem; ud : TMapItemUndoType); // Add an Item

    procedure ItemDel (mp : TMapItem; ud : TMapItemUndoType);

    procedure ItemMove    (mp : TMapItem; pDist : TPoint ; ud : TMapItemUndoType);
    procedure ItemRotate  (mp : TMapItem; ang : real ; ud : TMapItemUndoType);
    procedure ItemScale   (mp : TMapItem; sX, sY : real ; ud : TMapItemUndoType);
    procedure ItemPntNew  (mp : TMapItem; ind : integer ; pnt : TPoint; ud : TMapItemUndoType);
    procedure ItemPntDel  (mp : TMapItem; ind : integer ; ud : TMapItemUndoType);
    procedure ItemPntMove (mp : TMapItem; ind : integer ; ud : TMapItemUndoType);

    procedure ItemNameUpdate (mp : TMapItem; sName : string; ud : TMapItemUndoType);
    procedure ItemDescUpdate (mp : TMapItem; sDesc : string; ud : TMapItemUndoType);

    function  UndoLast (var ud : TMapItemUndoType): TMapItem; // Undo and return pointer to item
    function  InqUndoLen : integer;
    procedure UndoReset; // Remove all undo things
    function  InqNextUndoInfo : string;
  private
    procedure UndoMoveAllUp; // Move all undo up one and make index 1 free

end;

implementation

//------------------------------------------------------------------------------
// Save / Load Item Types
//
var
  LeafsItemList : TLeafRecordArray;

//------------------------------------------------------------------------------
//                                 Constructors
//------------------------------------------------------------------------------
// Initialize the Map Data Object
//
constructor TMapItemList.Create();
begin
  inherited create;

  MapUndoListLen := 0;

  MapUndoMaxReached := false;
  MapUndoLenAtSave := 0;
end;
//------------------------------------------------------------------------------
//                           Loading and Saving Map Items
//------------------------------------------------------------------------------
// Save this item type to file
//
function TMapItemList.SaveToFile (var F : TextFile) : boolean;
var
  i : integer;
  it : TMapItem;
begin
  SaveToFile := true;

  { Save semantics
    The Calling function will wrap it into itemtypelist

    for each item type do

    <itemtype=
    ... item types attributes
    >

  }

  for i := 0 to Count - 1 do
    begin
      it := Items[i];
      if it <> nil then
        begin
          // Put the header

          WriteLn(F, '<' + LeafGetName(LeafsItemList,LeafItem) + '=');

          // Save the item type

          it.SaveToFile(F);

          // Put the end

          WriteLn(F, '>');
        end;
    end;
  MapUndoLenAtSave := MapUndoListLen;
  MapUndoMaxReached := false;
end;
//------------------------------------------------------------------------------
// Load this item from to file
//
function TMapItemList.LoadFromFile (var F : TextFile; pMitl : TMapItemTypeList) : boolean;
var
  sBuf : string;
  id   : integer;
  it   : TMapItem;
begin
  LoadFromFile := false;

  while not Eof(F) do
    begin
      // Get the first object

      Readln(F, sBuf); // Syntax : <objectname=

      id := LeafGetId(LeafsItemList, LeafGetObjectName(sBuf));
      case id of
        LeafObjectAtEnd  : break;
        LeafItem :
          begin
            it := TMapItem.Create;
            it.LoadFromFile(F, pMitl);
            Add(it);
          end
      else
        // Unknown object, skip it
        LeafSkipObject(F);
      end;
    end;
end;
//------------------------------------------------------------------------------
// Inq if map is dirty (has changed)
//
function TMapItemList.InqDirty : boolean;
begin
  InqDirty := false;

  // If no undo (nothing changed or all is undone)

  if (Self.Count > 0) and
     ( (MapUndoListLen <> MapUndoLenAtSave) or
        MapUndoMaxReached ) then
    begin
      InqDirty := true;
    end;
end;
//------------------------------------------------------------------------------
//  Clear all map points and free memory
//
procedure TMapItemList.Clear;
var
  i : integer;
  p : TMapItem;
begin

  Pack; // Remove empty points (if any)

  // Walk all Points and destroy them

  for i := 0 to (Count - 1) do
    begin
      p := Items[i];
      if p <> nil then
        p.Free;
    end;

  Pack; // Remove empty points (if any)

  // Free anything in UndoList

  for i := 1 to MapUndoListLen do
    begin
      if ((MapUndoList[i].UndoType = udDelItem) or
          (MapUndoList[i].UndoType = udSetType)) and
         (MapUndoList[i].UndoItem <> nil) then
        MapUndoList[i].UndoItem.Free;
    end;

  UndoReset;

  // Do the TList stuff;

  inherited Clear;
end;
//------------------------------------------------------------------------------
//                                Read only functions
//------------------------------------------------------------------------------
// Get the number of points in the Map Data Object
//
function TMapItemList.InqPoints : integer;
begin
  InqPoints := Count;
end;
//---------------------------------------------------------------------------
// Find out if a point is inside any Map Points and return its index
//
function TMapItemList.InqPoint (pMap : TPoint) : TMapItem;
var
  i : integer;
  po,pn : TMapItem;
  so,sn : integer;
begin
  po := nil;
  so := 99999;
  
  for i := 0 to Count - 1 do
    begin
      // Get the point from index

      pn := Items[i];

      // Test if point is visible and at the position

      if (pn <> nil) then
        if InqPointIsVisible(pn) then
          if pn.InqAtPos(pMap) then
            begin
              sn := InqRectSize(pn.InqExt());

              // Compare this with old point and its extension

              if po <> nil then
                begin
                  if sn < so then
                    begin
                      po := pn;
                      so := sn;
                    end;
                end
              else
                begin
                  po := pn;
                  so := sn;
                end;
            end;
    end;

  InqPoint := po;
end;
//---------------------------------------------------------------------------
// Find the point that has a specific name
//
function TMapItemList.InqPoint (sName : string) : TMapItem;
var
  i : integer;
  p : TMapItem;
begin
  InqPoint := nil;

  for i := 0 to Count - 1 do
  begin
    // Get the point from index

    p := Items[i];

    // Test if point has the right name

    if (p <> nil) then
      if (AnsiCompareText(p.InqName, sName) = 0) then
        begin
          InqPoint := p;
          exit;
        end;
  end;
end;
//------------------------------------------------------------------------------
// Return a pointer to the Map Point of an item at index
//
function TMapItemList.InqPoint (index : integer) : TMapItem;
begin
  InqPoint := nil;
  if (index >= 0) and (index < Count) then
    begin
      InqPoint := Items[index];
    end
end;
//------------------------------------------------------------------------------
// Return if an Map Point is visible
//
function TMapItemList.InqPointIsVisible (mp : TMapItem) : boolean;
begin
  if mp <> nil then
    InqPointIsVisible := mp.InqVisible()
  else
    InqPointIsVisible := false;
end;
//---------------------------------------------------------------------------
// Return a unique name for an item built from input name
//
function TMapItemList.GetUniqueName (sName : string) : string;
var
  j    : integer;
  p    : TMapItem;
  sTmp : string;
begin
  GetUniqueName := sName;

  for j := 0 to 99 do
    begin
      // Build the name to test

      if j = 0 then
        sTmp := sName
      else
        sTmp := sName + IntToStr(j);

      // Does it exist

      p := InqPoint(sTmp);
      if p = nil then
        begin
          GetUniqueName := sTmp;
          Exit;
        end;
    end;
end;
//------------------------------------------------------------------------------
//                          Changing and Undoing Items
//------------------------------------------------------------------------------
//  Add an Item to the Map
procedure TMapItemList.ItemNew(mp : TMapItem; ud : TMapItemUndoType);
begin
  if mp <> nil then
    begin
      // Add the item to the TList

      Add (mp);

      // Add the Undo Stuff

      UndoMoveAllUp;

      MapUndoList[1].UndoType := ud;
      MapUndoList[1].UndoItem := mp;
      MapUndoList[1].UndoItemOld := nil;
    end;
end;
//------------------------------------------------------------------------------
//  Delete item
//
procedure TMapItemList.ItemDel (mp : TMapItem; ud : TMapItemUndoType);
begin
  if (mp <> nil) then
    begin
      // remove the item from TList

      Remove (mp);

      // Add the Undo Stuff

      UndoMoveAllUp;

      MapUndoList[1].UndoType := ud;
      MapUndoList[1].UndoItem := nil;
      MapUndoList[1].UndoItemOld := mp;

    end;
end;
//------------------------------------------------------------------------------
//  Move an item a specified distance
//
procedure TMapItemList.ItemMove (mp : TMapItem; pDist : TPoint ; ud : TMapItemUndoType);
begin
  if (mp <> nil) then
    begin
      // Move the item

      mp.Move(pDist);

      // Add the Undo Stuff

      UndoMoveAllUp;

      MapUndoList[1].UndoType  := ud;
      MapUndoList[1].UndoItem  := mp;
      MapUndoList[1].UndoPoint.X := - pDist.X;
      MapUndoList[1].UndoPoint.Y := - pDist.Y;
      MapUndoList[1].UndoItemOld := nil;

    end;
end;
//------------------------------------------------------------------------------
//  Move an item a specified distance
//
procedure TMapItemList.ItemRotate (mp : TMapItem; ang : real ; ud : TMapItemUndoType);
begin
  if (mp <> nil) then
    begin
      // Add the Undo Stuff

      UndoMoveAllUp;

      MapUndoList[1].UndoType  := ud;
      MapUndoList[1].UndoItem  := mp;
      MapUndoList[1].UndoReal  := ang;
      MapUndoList[1].UndoPoint := mp.InqMidPoint;
      MapUndoList[1].UndoItemOld := nil;

      // Move the item

      mp.Rotate(MapUndoList[1].UndoPoint, ang);
    end;
end;
//------------------------------------------------------------------------------
//  Move an item a specified distance
//
procedure TMapItemList.ItemScale (mp : TMapItem; sX, sY : real ; ud : TMapItemUndoType);
begin
  if (mp <> nil) then
    begin
      // Add the Undo Stuff

      UndoMoveAllUp;

      MapUndoList[1].UndoType  := ud;

      // Make a copy and remember that in the undo buffer

      MapUndoList[1].UndoItem     := mp;
      MapUndoList[1].UndoItemOld  := mp.Copy;

      // Scale the item

      mp.Scale(mp.InqMidPoint, sX, sY);
    end;
end;
//------------------------------------------------------------------------------
//  Add a new point to the item
//
procedure TMapItemList.ItemPntNew (mp : TMapItem; ind : integer ; pnt : TPoint; ud : TMapItemUndoType);
begin
  if (mp <> nil) then
    begin
      // Add the Undo Stuff

      UndoMoveAllUp;

      MapUndoList[1].UndoType  := ud;
      MapUndoList[1].UndoItem  := mp;
      MapUndoList[1].UndoPoint := mp.InqPos (ind);
      MapUndoList[1].UndoIndex := ind;
      MapUndoList[1].UndoItemOld := nil;

      // Delete the item point also

      mp.AddPoint(ind, pnt);
    end;
end;
//------------------------------------------------------------------------------
//  Move an item a specified distance
//
procedure TMapItemList.ItemPntDel (mp : TMapItem; ind : integer ; ud : TMapItemUndoType);
begin
  if (mp <> nil) then
    begin
      // Add the Undo Stuff

      UndoMoveAllUp;

      MapUndoList[1].UndoType  := ud;
      MapUndoList[1].UndoItem  := mp;
      MapUndoList[1].UndoPoint := mp.InqPos (ind);
      MapUndoList[1].UndoIndex := ind;
      MapUndoList[1].UndoItemOld := nil;

      // Delete the item point also

      mp.DelPoint(ind);
    end;
end;
//------------------------------------------------------------------------------
//  Move an item position a specified distance
//
procedure TMapItemList.ItemPntMove (mp : TMapItem; ind : integer ; ud : TMapItemUndoType);
begin
  if (mp <> nil) then
    begin
      // Just remember the index and the point

      UndoMoveAllUp;

      MapUndoList[1].UndoType  := ud;
      MapUndoList[1].UndoItem  := mp;
      MapUndoList[1].UndoPoint.X := mp.InqPos(ind).X;
      MapUndoList[1].UndoPoint.Y := mp.InqPos(ind).Y;
      MapUndoList[1].UndoIndex := ind;
      MapUndoList[1].UndoItemOld := nil;
    end;
end;
//------------------------------------------------------------------------------
//  Update the name of an item
//
procedure TMapItemList.ItemNameUpdate (mp : TMapItem; sName : string; ud : TMapItemUndoType);
begin
  if (mp <> nil) then
    if CompareText(sName,mp.InqName) <> 0 then
      begin
        // Set it up

        UndoMoveAllUp;
        MapUndoList[1].UndoType  := ud;
        MapUndoList[1].UndoItem  := mp;
        MapUndoList[1].UndoString := mp.InqName();
        MapUndoList[1].UndoItemOld := nil;

        // Change the name

        mp.SetName (sName);
      end;
end;
//------------------------------------------------------------------------------
//  Update the description of an item
//
procedure TMapItemList.ItemDescUpdate (mp : TMapItem; sDesc : string; ud : TMapItemUndoType);
begin
  if (mp <> nil) then
    begin
      // Set it up

      UndoMoveAllUp;
      MapUndoList[1].UndoType  := ud;
      MapUndoList[1].UndoItem  := mp;
      MapUndoList[1].UndoString := mp.InqDesc();
      MapUndoList[1].UndoItemOld := nil;

      // Change the description

      mp.SetDesc (sDesc);
    end;
end;
//------------------------------------------------------------------------------
//  Undo and return pointer to item
//
function TMapItemList.UndoLast (var ud : TMapItemUndoType) : TMapItem;
var
  i : integer;
begin
  UndoLast := nil;
  ud       := udNone;

  if (MapUndoListLen > 0) and (MapUndoList[1].UndoType <> udNone) then
    begin
      // Undo the last change (index 1)

      case MapUndoList[1].UndoType of
        udNewItem, udPasteItem:
          if MapUndoList[1].UndoItem <> nil then
            begin
              // Remove the item fram TList

              Remove(MapUndoList[1].UndoItem);

              // return the item

              ud := MapUndoList[1].UndoType;
              UndoLast := MapUndoList[1].UndoItem;

            end;
        udDelItem:
          if MapUndoList[1].UndoItemOld <> nil then
            begin
              // Add the item back to the TList again

              Add(MapUndoList[1].UndoItemOld);

              // return the item

              ud := MapUndoList[1].UndoType;
              UndoLast := MapUndoList[1].UndoItemOld;
            end;
        udMoveMid, udMoveItem:
          if MapUndoList[1].UndoItem <> nil then
            begin
              // Move the item back

              MapUndoList[1].UndoItem.Move (MapUndoList[1].UndoPoint);

              ud := MapUndoList[1].UndoType;
              UndoLast := MapUndoList[1].UndoItem;
            end;
        udRotateItem:
          if MapUndoList[1].UndoItem <> nil then
            begin
              // Rotate the item back

              MapUndoList[1].UndoItem.Rotate (MapUndoList[1].UndoPoint, - MapUndoList[1].UndoReal);

              ud := MapUndoList[1].UndoType;
              UndoLast := MapUndoList[1].UndoItem;
            end;
        udScaleItem:
          if MapUndoList[1].UndoItem <> nil then
            begin
              // Copy the coordinates back to the item and free the copy

              MapUndoList[1].UndoItem.CopyProp(MapUndoList[1].UndoItemOld);

              // Free the old item

              MapUndoList[1].UndoItemOld.Free;

              ud := MapUndoList[1].UndoType;
              UndoLast := MapUndoList[1].UndoItem;

            end;
        udNewPnt:
          if MapUndoList[1].UndoItem <> nil then
            begin
              // Remove the point agai

              MapUndoList[1].UndoItem.DelPoint(MapUndoList[1].UndoIndex);

              ud := MapUndoList[1].UndoType;
              UndoLast := MapUndoList[1].UndoItem;

            end;
        udDelPnt:
          if MapUndoList[1].UndoItem <> nil then
            begin
              // Add the pos again

              MapUndoList[1].UndoItem.AddPoint(MapUndoList[1].UndoIndex,
                                                  MapUndoList[1].UndoPoint);

              ud := MapUndoList[1].UndoType;
              UndoLast := MapUndoList[1].UndoItem;

            end;
        udMovePnt:
          if MapUndoList[1].UndoItem <> nil then
            begin
              // Set back the coordinate again

              MapUndoList[1].UndoItem.SetPoint(MapUndoList[1].UndoIndex, MapUndoList[1].UndoPoint);

              ud := MapUndoList[1].UndoType;
              UndoLast := MapUndoList[1].UndoItem;

            end;
        udEditName:
          if MapUndoList[1].UndoItem <> nil then
            begin
              // Set the name back

              MapUndoList[1].UndoItem.SetName (MapUndoList[1].UndoString);
              ud := MapUndoList[1].UndoType;
              UndoLast := MapUndoList[1].UndoItem;
            end;
        udEditDesc:
          if MapUndoList[1].UndoItem <> nil then
            begin
              // Set the description back

              MapUndoList[1].UndoItem.SetDesc (MapUndoList[1].UndoString);
              ud := MapUndoList[1].UndoType;
              UndoLast := MapUndoList[1].UndoItem;
            end;

        end;

      // Move all undo records down again

      for i:= 1 to MapUndoListLen - 1 do
        MapUndoList[i] := MapUndoList[i+1];

      MapUndoListLen := Max(0, MapUndoListLen - 1);
    end;
end;
//------------------------------------------------------------------------------
//  Return number of undo stored
//
function TMapItemList.InqUndoLen : integer;
begin
  InqUndoLen := MapUndoListLen;
end;
//------------------------------------------------------------------------------
//  Move all undo records upp one index to make index = 1 free for next undo
//
procedure TMapItemList.UndoMoveAllUp;
var
  i : integer;
begin
  MapUndoListLen := MapUndoListLen + 1;

  if MapUndoListLen > MapUndoListMaxLen then
    begin
      MapUndoMaxReached := true;
      MapUndoListLen := MapUndoListMaxLen;
    end;

  for i:= MapUndoListLen downto 2 do
    MapUndoList[i] := MapUndoList[i-1];

end;
//------------------------------------------------------------------------------
//  Reset all Undo things
//
procedure TMapItemList.UndoReset;
var
  i : integer;
begin
  // Remove all copied items not used any more

  for i:= 1 to MapUndoListLen do
    if MapUndoList[i].UndoItemOld <> nil then
       MapUndoList[i].UndoItemOld.Free;

  MapUndoListLen := 0;
  MapUndoMaxReached := false;
  MapUndoLenAtSave := 0;
end;
//------------------------------------------------------------------------------
//  Return information of last undo
//
function TMapItemList.InqNextUndoInfo : string;
var
  sTmp : string;
begin
  if MapUndoListLen > 0 then
    begin
      sTmp := '-';

      case MapUndoList[1].UndoType of
        udNewItem   : sTmp := 'item inserted';
        udPasteItem : sTmp := 'item pasted';
        udDelItem   : sTmp := 'item deleted';
        udSetType   : sTmp := 'item type changed';
        udMoveItem  : sTmp := 'item moved';
        udMoveMid   : sTmp := 'item moved to middle';
        udScaleItem : sTmp := 'item scaled';
        udRotateItem: sTmp := 'item rotated';
        udEditName  : sTmp := 'item name changed';
        udEditDesc  : sTmp := 'item description changed';
        udMovePnt   : sTmp := 'item point moved';
        udNewPnt    : sTmp := 'item point inserted';
        udDelPnt    : sTmp := 'item point deleted';
        udNone      : sTmp := 'nothing';
      end;
      if MapUndoList[1].UndoItem <> nil then
        InqNextUndoInfo := MapUndoList[1].UndoItem.InqName() + ' (' + sTmp + ')'
      else if MapUndoList[1].UndoItemOld <> nil then
        InqNextUndoInfo := MapUndoList[1].UndoItemOld.InqName() + ' (' + sTmp + ')'
      else
        InqNextUndoInfo := sTmp;
    end
  else
    InqNextUndoInfo := 'Nothing to undo';
end;
//------------------------------------------------------------------------------
//  Initialize all Save/Load arrays
//
initialization

// Add all necessary leafs for this object

  LeafAdd (LeafsItemList, LeafItem,     'Item',     atUnknown);

end.

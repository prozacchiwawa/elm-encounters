module Encounter where

import Utilities exposing (..)
import StatTables
import Character
import Monster
import Effects exposing (Effects)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Dict exposing (Dict)
import String
import Debug

-- FEATURES

-- List of characters:
-- -- Have levels
-- -- Have XP thresholds for each difficulty (according table)
-- -- Defaults to 5 characters
-- -- Remembers your character list with localStorage
-- List of monsters:
-- -- Have XP values (input from user)
-- -- Have Challenge Rating (input from user)
-- -- Visual indication of difficulty?
-- -- Number of monsters adds a multiplier
-- Show Encounter difficulty
-- -- Show Party XP threshold for easy, medium, hard, deadly
-- -- Have a strong visual indication of encounter difficulty. Use cool pictures. Be creative!
--
-- Steps for encounter calculation
-- 1. Determine XP thresholds for each character
-- 2. Determine party XP thresholds by adding all character thresholds
-- 3. Total monster XP
-- 4. Modify monster total for multiple monsters
-- 5. Compare XP. Closest party threshold that is lower than monster XP determines difficulty

-- TODO
-- Remember char list with localStorage
-- Design UI
-- Enhance flows by shifting focus
-- Display difficulty


-- MODEL

type alias ID = Int

type alias PartyThresholds =
  { easy : Int
  , medium : Int
  , hard : Int
  , deadly : Int
  }

type alias Model =
  { uid : ID
  , party : List (ID, Character.Model)
  , partyThresholds : PartyThresholds
  , newCharacterLevel : Int
  , newCharacterName : String
  , monsters : List (ID, Monster.Model)
  , monsterXpTotal : Float
  , newMonsterName : String
  , newMonsterRating : Float
  , newMonsterXP : Int
  }

initParty : List (ID, Character.Model)
initParty =
  [ (1, Character.init)
  , (2, Character.init)
  , (3, Character.init)
  , (4, Character.init)
  , (5, Character.init)
  ]

levelsFromParty : List (ID, Character.Model) -> List Int
levelsFromParty party =
  List.map (snd >> .level) party

initPartyThresholds : PartyThresholds
initPartyThresholds =
  calculatePartyThresholds <| levelsFromParty initParty

init : (Model, Effects Action)
init =
  ( { uid = List.length initParty + 1
    , party = initParty
    , partyThresholds = initPartyThresholds
    , newCharacterLevel = 1
    , newCharacterName = "" 
    , monsters = []
    , monsterXpTotal = 0
    , newMonsterName = "" 
    , newMonsterRating = initRating 
    , newMonsterXP = safeRatingToXP initRating }
  , Effects.none)

-- UPDATE

type Action
  = NoOp
  | AddCharacter Character.Model
  | RemoveCharacter ID
  | ModifyCharacter ID Character.Action
  | SetNewCharacterLevel Int
  | SetNewCharacterName String
  | AddMonster Monster.Model
  | RemoveMonster ID
  | ModifyMonster ID Monster.Action
  | SetNewMonsterName String
  | SetNewMonsterXP Int
  | SetNewMonsterRating Float

update : Action -> Model -> (Model, Effects Action)
update action model =
  case action of
    NoOp ->
      (model, Effects.none)
    AddCharacter character ->
      let
        newParty = (model.uid, character) :: model.party
      in
        ({ model |
             party = newParty,
             partyThresholds = calculatePartyThresholds <| levelsFromParty newParty,
             uid = model.uid + 1 }
        , Effects.none)
    RemoveCharacter id ->
      let
        newParty = List.filter (\(characterID, _) -> characterID /= id) model.party 
      in
        ({ model |
             party = newParty,
             partyThresholds = calculatePartyThresholds <| levelsFromParty newParty }
        , Effects.none)
    ModifyCharacter id characterAction ->
      let
        updateCharacter (characterID, characterModel) =
          if id == characterID then
            (characterID, fst <| Character.update characterAction characterModel)
          else
            (characterID, characterModel)
        newParty = List.map updateCharacter model.party 
      in
        ({ model |
             party = newParty,
             partyThresholds = calculatePartyThresholds <| levelsFromParty newParty }
        , Effects.none)
    SetNewCharacterLevel level ->
      ({ model | newCharacterLevel = level }, Effects.none)
    SetNewCharacterName name ->
      ({ model | newCharacterName = name }, Effects.none)
    AddMonster monster ->
      let
        newMonsters = (model.uid, monster) :: model.monsters
      in
        ({ model |
             monsters = newMonsters,
             monsterXpTotal = calculateMonsterXPTotal newMonsters,
             uid = model.uid + 1 }
        , Effects.none)
    RemoveMonster id ->
      let
        newMonsters = List.filter (\(monsterID, _) -> monsterID /= id) model.monsters 
      in
        ({ model |
             monsters = newMonsters,
             monsterXpTotal = calculateMonsterXPTotal newMonsters }
        , Effects.none)
    ModifyMonster id monsterAction ->
      let
        updateMonster (monsterID, monsterModel) =
          if id == monsterID then
            (monsterID, fst <| Monster.update monsterAction monsterModel)
          else
            (monsterID, monsterModel)
        newMonsters = List.map updateMonster model.monsters 
      in
        ({ model |
             monsters = newMonsters,
             monsterXpTotal = calculateMonsterXPTotal newMonsters }
        , Effects.none)
    SetNewMonsterName name ->
      ({ model | newMonsterName = name }, Effects.none)
    SetNewMonsterRating rating ->
      ({ model |
           newMonsterRating = Debug.log (toString rating) rating,
           newMonsterXP = safeRatingToXP rating }
       , Effects.none)
    SetNewMonsterXP xp ->
      ({ model |
           newMonsterRating = safeXPToRating xp,
           newMonsterXP = xp }
       , Effects.none)

-- VIEW

view : Signal.Address Action -> Model -> Html
view address model =
  div
    [ class "main" ]
    [
      titleSectionView
    , partySectionView address model
    , monsterSectionView address model
    , encounterSummaryView address model
    , debugView model
    ]

encounterSummaryView : Signal.Address Action -> Model -> Html
encounterSummaryView address model =
  section 
    [ class "encounter-summary-section" ]
    [
      difficultyBadgeView model
    , partySummaryView model 
    , monsterSummaryView model
    ]

difficultyBadgeView : Model -> Html
difficultyBadgeView model =
  let
    badgeClass = "badge badge--" ++ calculateDifficulty model
  in
    div 
      [ class badgeClass ]
      [ strong [ class "difficulty" ] [text <| calculateDifficulty model] ]

titleSectionView : Html
titleSectionView =
  section
    [ class "title-section" ]
    [
      h1 [ class "title" ] [ text "D&D 5th Edition Encounter Builder" ]
    , p
        [ class "description" ]
        [ text "This encounter builder allows you to easily determine the difficulty
          of your 5th edition encounters. Simply create a list of party members
          and a list of monsters, and the encounter builder will tell you if
          it will be a cake walk or a total party kill." ]
    ]

partySectionView : Signal.Address Action -> Model -> Html
partySectionView address model = 
  section 
    [ class "party-section" ]
    [
      h2 [] [text "The party"]
    , partySummaryView model
    , h3 [] [text "Add new character"]
    , addCharacterView address model
    , h3 [] [text "Current party"]
    , div
        [ class "current-party-tools" ]
        [
          button [ class "toggle-party-view" ] [ text "view current party" ]
        ]
    , characterListView address model
    ]

partySummaryView : Model -> Html
partySummaryView model =
  let
    members = "Members: " ++ (toString <| List.length model.party)
    thresholds = 
      "XP: " ++
      toString model.partyThresholds.easy ++ " | " ++
      toString model.partyThresholds.medium ++ " | " ++
      toString model.partyThresholds.hard ++ " | " ++
      toString model.partyThresholds.deadly
  in
    div
      [ class "party-summary" ]
      [
        text (members ++ " " ++ thresholds)
      ]

characterListView : Signal.Address Action -> Model -> Html
characterListView address model =
  div
    [ class "characters" ]
    (List.map (characterView address) model.party)

monsterSectionView : Signal.Address Action -> Model -> Html
monsterSectionView address model = 
  section 
    [ class "monster-section" ]
    [
      h2 [] [text "The monsters"]
    , monsterSummaryView model
    , h3 [] [text "Add new monster"]
    , addMonsterView address model
    , h3 [] [text "Current monsters"]
    , div
        [ class "current-monster-tools" ]
        [
          button [ class "set-monster-cr-view" ] [ text "CR" ]
        , button [ class "set-monster-xp-view" ] [ text "XP" ]
        , button [ class "toggle-monster-view" ] [ text "view current monsters" ]
        ]
    , monsterListView address model
    ]

monsterSummaryView : Model -> Html
monsterSummaryView model =
  let
    monsters = "Monsters: " ++ (toString <| List.length model.monsters)
    threat = 
      "XP: " ++
      toString model.monsterXpTotal
  in
    div
      [ class "monster-summary" ]
      [
        text (monsters ++ " " ++ threat)
      ]

monsterListView : Signal.Address Action -> Model -> Html
monsterListView address model =
  div
    []
    (List.map (monsterView address) model.monsters)

debugView model =
  p [] [ text <| toString <| model ]

addMonsterView : Signal.Address Action -> Model -> Html
addMonsterView address model =
  div
    []
    [ label
        [ for "monster-rating" ]
        [ text "Challenge Rating" ]
    , monsterRatingOptionsView address model
    , label
        [ for "monster-xp" ]
        [ text "Experience Points" ]
    , monsterXpOptionsView address model
    , label
        [ for "monster-name" ]
        [ text "Name" ]
    , input
        [ type' "text" 
        , value model.newMonsterName
        , on "input" targetValue (\name -> Signal.message address (SetNewMonsterName name))
        ]
        []
    , button
        [ onClick address (AddMonster (Monster.new model.newMonsterRating model.newMonsterName)) ]
        [ text "Add Monster"]
    ]

monsterView : Signal.Address Action -> (ID, Monster.Model) -> Html
monsterView address (id, model) =
  let
    context = 
      Monster.Context
        (Signal.forwardTo address (ModifyMonster id))
        (Signal.forwardTo address (always (RemoveMonster id)))
  in
    Monster.view context model

monsterRatingOptionsView : Signal.Address Action -> Model -> Html
monsterRatingOptionsView address model =
  let 
    monsterRatingOption rating isSelected =
      option
        [ value rating 
        , selected isSelected
        ]
        [ text rating ]
    monsterRatingOptions =
      List.map
        (\rating -> monsterRatingOption (toString rating) (rating == model.newMonsterRating))
        StatTables.ratingList
  in
    select 
      [ name "monster-rating"
      , on "change" targetValue (\rating -> Signal.message address (SetNewMonsterRating (safeStrToRating rating))) 
      ]
      monsterRatingOptions

monsterXpOptionsView : Signal.Address Action -> Model -> Html
monsterXpOptionsView address model =
  let 
    monsterXpOption xp isSelected =
      option
        [ value xp 
        , selected isSelected  
        ]
        [ text xp ]
    monsterXpOptions =
      List.map
        (\xp -> monsterXpOption (toString xp) (xp == model.newMonsterXP))
        StatTables.xpList
  in
    select 
      [ name "monster-xp"
      , on "change" targetValue (\xp -> Signal.message address (SetNewMonsterXP (safeStrToLevel xp)))
      ]
      monsterXpOptions

partyThresholdsView : PartyThresholds -> Html
partyThresholdsView partyThresholds =
  p
    []
    [ text (partyThresholds |> toString) ]

addCharacterView : Signal.Address Action -> Model -> Html
addCharacterView address model =
  div 
    []
    [ label
        [ for "level" ]
        [ text "Level" ]
    , levelOptionsView address model
    , label 
        [ for "name" ]
        [ text "Name" ]
    , input
        [ type' "text"
        , value model.newCharacterName
        , on "input" targetValue (\name -> Signal.message address (SetNewCharacterName name))
        ]
        []
    , button
        [ onClick address (AddCharacter (Character.new model.newCharacterLevel model.newCharacterName)) ]
        [ text "Add Character"]
    ] 

levelOptionsView : Signal.Address Action -> Model -> Html
levelOptionsView address model =
  let 
    levelOption level isSelected =
      option
        [ value level 
        , selected isSelected
        ]
        [ text level ]
    levelOptions =
      List.map
        (\level -> levelOption (toString level) (level == model.newCharacterLevel))
        StatTables.levelList
  in
    select 
      [ name "character-level"
      , on "change" targetValue (\level -> Signal.message address (SetNewCharacterLevel (safeStrToLevel level))) 
      ]
      levelOptions

characterView : Signal.Address Action -> (ID, Character.Model) -> Html
characterView address (id, model) =
  let
    context = 
      Character.Context
        (Signal.forwardTo address (ModifyCharacter id))
        (Signal.forwardTo address (always (RemoveCharacter id)))
  in
    Character.view context model

calculatePartyThresholds : List Int -> PartyThresholds
calculatePartyThresholds levels =
  let
    easyPartyThresholds =
      List.map getEasyThreshold levels
    mediumPartyThresholds =
      List.map getMediumThreshold levels
    hardPartyThresholds =
      List.map getHardThreshold levels
    deadlyPartyThresholds =
      List.map getDeadlyThreshold levels
  in
    { easy = List.sum easyPartyThresholds
    , medium = List.sum mediumPartyThresholds
    , hard = List.sum hardPartyThresholds
    , deadly = List.sum deadlyPartyThresholds
    }

calculateMonsterMultiplier : List (ID, Monster.Model) -> Float
calculateMonsterMultiplier taggedMonsters =
  let
    monsterCount = List.length taggedMonsters
  in
    if (monsterCount == 0 || monsterCount == 1) then
      1
    else if (monsterCount >= 2 || monsterCount < 3) then
      1.5
    else if (monsterCount >= 3 || monsterCount < 7) then
      2
    else if (monsterCount >= 7 || monsterCount < 11) then
      2.5
    else if (monsterCount >= 11 || monsterCount < 15) then
      3
    else
      4

calculateMonsterXPTotal : List (ID, Monster.Model) -> Float
calculateMonsterXPTotal taggedMonsters =
  let
    monsters = List.map snd taggedMonsters
    totalMonsterXPs = List.sum (List.map .xp monsters)
    multiplier = calculateMonsterMultiplier taggedMonsters
  in
    toFloat totalMonsterXPs * multiplier

calculateDifficulty : Model -> String
calculateDifficulty model =
  if (round model.monsterXpTotal < model.partyThresholds.easy) then
    "easy"
  else if (round model.monsterXpTotal < model.partyThresholds.medium) then
    "medium"
  else if (round model.monsterXpTotal < model.partyThresholds.hard) then
    "hard"
  else if (round model.monsterXpTotal < model.partyThresholds.deadly) then
    "deadly"
  else
    "TPK"

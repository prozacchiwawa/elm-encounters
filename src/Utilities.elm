module Utilities (safeStrToLevel, safeStrToRating, safeRatingToXP, safeXPToRating, initRating, getEasyThreshold, getMediumThreshold, getHardThreshold, getDeadlyThreshold) where

import StatTables
import String
import Dict exposing (Dict)

safeStrToLevel : String -> Int
safeStrToLevel =
  String.toInt >> Result.toMaybe >> Maybe.withDefault 0

safeStrToRating : String -> Float
safeStrToRating =
  String.toFloat >> Result.toMaybe >> Maybe.withDefault 0

safeXPToRating : Int -> Float
safeXPToRating xp =
  Dict.get xp StatTables.xpRatingTable |> Maybe.withDefault 0

safeRatingToXP : Float -> Int
safeRatingToXP rating =
  Dict.get rating StatTables.ratingXPTable |> Maybe.withDefault 0

highestXP : Int
highestXP =
  List.maximum StatTables.xpList |> Maybe.withDefault 0

initRating : Float
initRating =
  List.head StatTables.ratingList |> Maybe.withDefault 0

getEasyThreshold =
  getThreshold StatTables.easyThresholds

getMediumThreshold =
  getThreshold StatTables.mediumThresholds

getHardThreshold = 
  getThreshold StatTables.hardThresholds

getDeadlyThreshold =
  getThreshold StatTables.deadlyThresholds

getThreshold : Dict Int Int -> Int -> Int
getThreshold thresholds level =
  Maybe.withDefault 0 <| Dict.get level thresholds

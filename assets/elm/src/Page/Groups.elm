module Page.Groups
    exposing
        ( Model
        , Msg(..)
        , init
        , setup
        , teardown
        , update
        , view
        )

import Html exposing (..)
import Html.Attributes exposing (..)
import Task exposing (Task)
import Connection exposing (Connection)
import Data.Group as Group exposing (Group)
import Data.Space as Space exposing (Space)
import Data.SpaceUser as SpaceUser exposing (SpaceUser)
import Query.GroupsInit as GroupsInit
import Repo exposing (Repo)
import Route
import Session exposing (Session)


-- MODEL


type alias Model =
    { space : Space
    , user : SpaceUser
    , groups : Connection Group
    }



-- LIFECYCLE


init : SpaceUser -> Space -> Session -> Task Session.Error ( Session, Model )
init user space session =
    session
        |> GroupsInit.request (Space.getId space) Nothing 10
        |> Task.andThen (buildModel user space)


buildModel : SpaceUser -> Space -> ( Session, GroupsInit.Response ) -> Task Session.Error ( Session, Model )
buildModel user space ( session, { groups } ) =
    Task.succeed ( session, Model space user groups )


setup : Model -> Cmd Msg
setup model =
    Cmd.none


teardown : Model -> Cmd Msg
teardown model =
    Cmd.none



-- UPDATE


type Msg
    = NoOp


update : Msg -> Repo -> Session -> Model -> ( ( Model, Cmd Msg ), Session )
update msg repo session model =
    ( ( model, Cmd.none ), session )



-- VIEW


view : Repo -> Model -> Html Msg
view repo model =
    div [ class "ml-56 mr-24" ]
        [ div [ class "mx-auto max-w-md leading-normal py-8" ]
            [ h1 [ class "pb-8 font-extrabold text-3xl" ] [ text "Group Directory" ]
            , groupsView repo model.groups
            ]
        ]


groupsView : Repo -> Connection Group -> Html Msg
groupsView repo connection =
    let
        partitions =
            connection
                |> Connection.toList
                |> partitionGroups repo []
    in
        div [ class "leading-semi-loose" ] <|
            List.map (groupPartitionView repo) partitions


groupPartitionView : Repo -> ( String, List Group ) -> Html Msg
groupPartitionView repo ( letter, groups ) =
    div [ class "flex" ]
        [ div [ class "flex-0 w-12 text-lg text-dusty-blue" ] [ text letter ]
        , div [ class "flex-1" ] <|
            List.map (groupView repo) groups
        ]


groupView : Repo -> Group -> Html Msg
groupView repo group =
    let
        groupData =
            Repo.getGroup repo group
    in
        div []
            [ h2 [ class "font-normal text-lg" ]
                [ a [ Route.href (Route.Group groupData.id), class "text-blue no-underline" ] [ text groupData.name ]
                ]
            ]



-- HELPERS


partitionGroups : Repo -> List ( String, List Group ) -> List Group -> List ( String, List Group )
partitionGroups repo partitions groups =
    case groups of
        hd :: tl ->
            let
                letter =
                    firstLetter repo hd

                ( matches, remaining ) =
                    List.partition (startsWith repo letter) groups
            in
                partitionGroups repo (( letter, matches ) :: partitions) remaining

        _ ->
            List.reverse partitions


firstLetter : Repo -> Group -> String
firstLetter repo group =
    group
        |> Repo.getGroup repo
        |> .name
        |> String.left 1
        |> String.toUpper


startsWith : Repo -> String -> Group -> Bool
startsWith repo letter group =
    firstLetter repo group == letter
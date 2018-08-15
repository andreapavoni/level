defmodule Level.Resolvers do
  @moduledoc """
  Functions for loading connections between resources, designed to be used in
  GraphQL query resolution.
  """

  import Absinthe.Resolution.Helpers

  alias Level.Resolvers.GroupMembershipConnection
  alias Level.Resolvers.GroupPostConnection
  alias Level.Resolvers.GroupConnection
  alias Level.Resolvers.MentionedPostConnection
  alias Level.Resolvers.ReplyConnection
  alias Level.Resolvers.SpaceUserConnection
  alias Level.Resolvers.UserGroupMembershipConnection
  alias Level.Groups
  alias Level.Groups.Group
  alias Level.Groups.GroupBookmark
  alias Level.Groups.GroupUser
  alias Level.Mentions
  alias Level.Mentions.UserMention
  alias Level.Pagination
  alias Level.Posts
  alias Level.Posts.Post
  alias Level.Posts.PostUser
  alias Level.Spaces
  alias Level.Spaces.Space
  alias Level.Spaces.SpaceUser
  alias Level.Users.User

  @typedoc "A info map for Absinthe GraphQL"
  @type info :: %{context: %{current_user: User.t(), loader: Dataloader.t()}}

  @typedoc "The return value for paginated connections"
  @type paginated_result :: {:ok, Pagination.Result.t()} | {:error, String.t()}

  @typedoc "The return value for a dataloader resolver"
  @type dataloader_result :: {:middleware, any(), any()}

  @doc """
  Fetches a space by id.
  """
  @spec space(map(), info()) :: {:ok, Space.t()} | {:error, String.t()}
  def space(%{id: id} = _args, %{context: %{current_user: user}} = _info) do
    case Spaces.get_space(user, id) do
      {:ok, %{space: space}} ->
        {:ok, space}

      error ->
        error
    end
  end

  @doc """
  Fetches a space membership by space id.
  """
  @spec space_user(map(), info()) :: {:ok, SpaceUser.t()} | {:error, String.t()}
  def space_user(%{space_id: id} = _args, %{context: %{current_user: user}} = _info) do
    case Spaces.get_space(user, id) do
      {:ok, %{space_user: space_user}} ->
        {:ok, space_user}

      error ->
        error
    end
  end

  @doc """
  Fetches a group by id.
  """
  @spec group(map(), info()) :: {:ok, Group.t()} | {:error, String.t()}
  def group(%{id: id} = _args, %{context: %{current_user: user}}) do
    Level.Groups.get_group(user, id)
  end

  @doc """
  Fetches space users belonging to a given user or a given space.
  """
  @spec space_users(User.t(), map(), info()) :: paginated_result()
  def space_users(%User{} = user, args, %{context: %{current_user: _user}} = info) do
    SpaceUserConnection.get(user, struct(SpaceUserConnection, args), info)
  end

  @spec space_users(Space.t(), map(), info()) :: paginated_result()
  def space_users(%Space{} = space, args, %{context: %{current_user: _user}} = info) do
    SpaceUserConnection.get(space, struct(SpaceUserConnection, args), info)
  end

  @doc """
  Fetches featured group memberships.
  """
  @spec featured_space_users(Space.t(), map(), info()) :: {:ok, [SpaceUser.t()]} | no_return()
  def featured_space_users(%Space{} = space, _args, %{context: %{current_user: _user}} = _info) do
    Level.Spaces.list_featured_users(space)
  end

  @doc """
  Fetches groups for given a space that are visible to the current user.
  """
  @spec groups(Space.t(), map(), info()) :: paginated_result()
  def groups(%Space{} = space, args, %{context: %{current_user: _user}} = info) do
    GroupConnection.get(space, struct(GroupConnection, args), info)
  end

  @doc """
  Fetches group memberships.
  """
  @spec group_memberships(User.t(), map(), info()) :: paginated_result()
  def group_memberships(%User{} = user, args, %{context: %{current_user: _user}} = info) do
    UserGroupMembershipConnection.get(user, struct(UserGroupMembershipConnection, args), info)
  end

  @spec group_memberships(Group.t(), map(), info()) :: paginated_result()
  def group_memberships(%Group{} = user, args, %{context: %{current_user: _user}} = info) do
    GroupMembershipConnection.get(user, struct(GroupMembershipConnection, args), info)
  end

  @doc """
  Fetches featured group memberships.
  """
  @spec featured_group_memberships(Group.t(), map(), info()) ::
          {:ok, [GroupUser.t()]} | no_return()
  def featured_group_memberships(group, _args, _info) do
    Level.Groups.list_featured_memberships(group)
  end

  @doc """
  Fetches posts within a given group.
  """
  @spec group_posts(Group.t(), map(), info()) :: paginated_result()
  def group_posts(%Group{} = group, args, info) do
    GroupPostConnection.get(group, struct(GroupPostConnection, args), info)
  end

  @doc """
  Fetches replies to a given post.
  """
  @spec replies(Post.t(), map(), info()) :: paginated_result()
  def replies(%Post{} = post, args, info) do
    ReplyConnection.get(post, struct(ReplyConnection, args), info)
  end

  @doc """
  Fetches a post by id.
  """
  @spec post(Space.t(), map(), info()) :: {:ok, Post.t()} | {:error, String.t()}
  def post(%Space{} = space, %{id: id} = _args, %{context: %{current_user: user}} = _info) do
    with {:ok, %{space_user: space_user}} <- Spaces.get_space(user, space.id),
         {:ok, post} <- Level.Posts.get_post(space_user, id) do
      {:ok, post}
    else
      error ->
        error
    end
  end

  @doc """
  Fetches mentions for the current user in a given scope.
  """
  @spec mentions(Post.t(), map(), info()) :: dataloader_result()
  def mentions(%Post{} = post, _args, %{context: %{loader: loader}}) do
    dataloader_one(loader, Mentions, {:many, UserMention}, post_id: post.id)
  end

  @doc """
  Fetches the current user's membership.
  """
  @spec group_membership(Group.t(), map(), info()) :: dataloader_result()
  def group_membership(%Group{} = group, _args, %{context: %{loader: loader}}) do
    dataloader_one(loader, Groups, {:one, GroupUser}, group_id: group.id)
  end

  @doc """
  Fetches is bookmarked status for a group.
  """
  @spec is_bookmarked(Group.t(), any(), info()) :: dataloader_result()
  def is_bookmarked(%Group{} = group, _, %{context: %{loader: loader}}) do
    source_name = Groups
    batch_key = {:one, GroupBookmark}
    item_key = [group_id: group.id]

    loader
    |> Dataloader.load(source_name, batch_key, item_key)
    |> on_load(fn loader ->
      loader
      |> Dataloader.get(source_name, batch_key, item_key)
      |> handle_bookmark_fetch()
    end)
  end

  defp handle_bookmark_fetch(%GroupBookmark{}), do: {:ok, true}
  defp handle_bookmark_fetch(_), do: {:ok, false}

  @doc """
  Fetches posts for which the current user has undismissed mentions.
  """
  @spec mentioned_posts(Space.t(), map(), info()) :: paginated_result()
  def mentioned_posts(%Space{} = space, args, info) do
    MentionedPostConnection.get(space, struct(MentionedPostConnection, args), info)
  end

  @doc """
  Fetches the current subscription state for a post.
  """
  @spec subscription_state(Post.t(), map(), info()) :: dataloader_result()
  def subscription_state(%Post{} = post, _, %{context: %{loader: loader}}) do
    source_name = Posts
    batch_key = {:one, PostUser}
    item_key = [post_id: post.id]

    loader
    |> Dataloader.load(source_name, batch_key, item_key)
    |> on_load(fn loader ->
      loader
      |> Dataloader.get(source_name, batch_key, item_key)
      |> handle_subscription_state_fetch()
    end)
  end

  defp handle_subscription_state_fetch(%PostUser{subscription_state: state}), do: {:ok, state}
  defp handle_subscription_state_fetch(_), do: {:ok, "NOT_SUBSCRIBED"}

  # Dataloader helpers

  defp dataloader_one(loader, source_name, batch_key, item_key) do
    loader
    |> Dataloader.load(source_name, batch_key, item_key)
    |> on_load(fn loader ->
      loader
      |> Dataloader.get(source_name, batch_key, item_key)
      |> tuplize()
    end)
  end

  defp tuplize(value), do: {:ok, value}
end

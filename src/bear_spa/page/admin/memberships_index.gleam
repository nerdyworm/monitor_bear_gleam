import bear/invitations/invitation.{type Invitation, Invitation}
import bear/memberships/membership.{type Membership, Membership}
import bear/tags
import bear/users/user
import bear_spa/api.{type ApiError}
import bear_spa/api/admin.{type MembershipPayload}
import bear_spa/app.{type App}
import bear_spa/view/modal
import bear_spa/view/ui
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import lustre/sub.{type Sub}
import validates.{type Errors}

pub type Model {
  Model(
    memberships: List(Membership),
    payload: MembershipPayload,
    invitation: Invitation,
    invitation_errors: List(Errors),
    confirming_remove: Bool,
    membership: Option(Membership),
    modal: modal.Model,
    modal_invite: modal.Model,
  )
}

pub type Msg {
  Save
  Invite
  InviteResponse(Result(MembershipPayload, ApiError))
  EditMembership(Membership)
  RemoveConfirm
  RemoveMembership(Membership)
  OpenModal
  OpenModalInvite
  CancelInvite
  ChangeInvitation(Invitation)
  ChangeMembership(Membership)
  UpdateMembership
  UpdateMembershipResponse(Result(Membership, ApiError))
  ModalMsg(modal.Msg(Msg))
  ModalInviteMsg(modal.Msg(Msg))
  Response(Result(MembershipPayload, ApiError))
}

pub fn init(app: App) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      memberships: [],
      payload: admin.MembershipPayload([], []),
      membership: None,
      confirming_remove: False,
      invitation: invitation.new(),
      invitation_errors: [],
      modal: modal.init(),
      modal_invite: modal.init(),
    )

  #(model, effect.batch([admin.list_memberships(app, Response)]))
}

pub fn update(app: App, model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Invite -> {
      #(model, admin.create_invitation(model.invitation, app, InviteResponse))
    }

    InviteResponse(Ok(_)) -> {
      let #(modal, effects) = modal.close(model.modal_invite)
      #(
        Model(..model, modal_invite: modal),
        effect.batch([
          admin.list_memberships(app, Response),
          effect.map(effects, ModalInviteMsg),
        ]),
      )
    }

    InviteResponse(response) -> {
      let _ = io.debug(response)
      #(model, effect.none())
    }

    ChangeInvitation(invitation) -> {
      #(Model(..model, invitation: invitation), effect.none())
    }

    Save -> {
      let #(modal, effects) = modal.close(model.modal)
      #(Model(..model, modal: modal), effect.map(effects, ModalMsg))
    }

    UpdateMembership -> {
      let assert Some(membership) = model.membership
      #(
        model,
        admin.update_membership(membership, app, UpdateMembershipResponse),
      )
    }

    UpdateMembershipResponse(Ok(_)) -> {
      let #(modal, effects) = modal.close(model.modal)
      #(
        Model(..model, modal: modal),
        effect.batch([
          admin.list_memberships(app, Response),
          effect.map(effects, ModalMsg),
        ]),
      )
    }

    UpdateMembershipResponse(response) -> {
      let _ = io.debug(response)
      #(model, effect.none())
    }

    EditMembership(membership) -> {
      let #(modal, effects) = modal.open(model.modal)
      #(
        Model(..model, modal: modal, membership: Some(membership)),
        effect.map(effects, ModalMsg),
      )
    }

    RemoveConfirm -> {
      #(Model(..model, confirming_remove: True), effect.none())
    }

    RemoveMembership(membership) -> {
      #(
        Model(..model, confirming_remove: False),
        admin.delete_membership(membership, app, UpdateMembershipResponse),
      )
    }

    OpenModal -> {
      let #(modal, effects) = modal.open(model.modal)
      #(Model(..model, modal: modal), effect.map(effects, ModalMsg))
    }

    OpenModalInvite -> {
      let #(modal, effects) = modal.open(model.modal_invite)
      #(
        Model(..model, modal_invite: modal),
        effect.map(effects, ModalInviteMsg),
      )
    }

    ChangeMembership(membership) -> {
      #(Model(..model, membership: Some(membership)), effect.none())
    }

    CancelInvite -> {
      let #(modal, effects) = modal.close(model.modal_invite)
      #(
        Model(..model, modal_invite: modal),
        effect.map(effects, ModalInviteMsg),
      )
    }

    ModalMsg(modal.Custom(msg)) -> {
      update(app, model, msg)
    }

    ModalMsg(submsg) -> {
      let #(modal, effects) = modal.update(model.modal, submsg)
      #(Model(..model, modal: modal), effect.map(effects, ModalMsg))
    }

    ModalInviteMsg(modal.Custom(msg)) -> {
      update(app, model, msg)
    }

    ModalInviteMsg(submsg) -> {
      let #(modal, effects) = modal.update(model.modal_invite, submsg)
      #(
        Model(..model, modal_invite: modal),
        effect.map(effects, ModalInviteMsg),
      )
    }

    Response(Ok(payload)) -> {
      #(Model(..model, payload: payload), effect.none())
    }

    Response(response) -> {
      let _ = io.debug(response)
      #(model, effect.none())
    }
  }
}

pub fn view(_app: App, model: Model) -> Element(Msg) {
  html.div(
    [attribute.id("membership-index"), attribute.class("membership-index")],
    [
      html.div([attribute.class("page-header")], [
        html.h1([], [html.text("Team Memberships")]),
        html.div([attribute.class("page-actions")], [
          html.a([attribute.href("/admin"), attribute.class("btn")], [
            html.text("Back"),
          ]),
          html.button(
            [event.on_click(OpenModalInvite), attribute.class("btn-primary")],
            [html.text("Invite new users")],
          ),
        ]),
      ]),
      html.div([attribute.class("page-body")], [
        view_memberships_table(model.payload.memberships, model),
      ]),
      view_membershp_modal(model),
      view_invite_modal(model),
    ],
  )
}

fn view_memberships_table(memberships: List(Membership), model: Model) {
  html.table([attribute.class("table")], [
    html.thead([], [
      html.tr([], [
        html.th([], [html.text("Email")]),
        html.th([], [html.text("Role")]),
        html.th([], [html.text("Tags")]),
        html.th([], []),
      ]),
    ]),
    html.tbody(
      [],
      list.map(memberships, fn(membership) {
        let user = get_user(membership, model)
        html.tr([], [
          html.td([], [html.text(user.email)]),
          html.td([], [html.text(membership.role)]),
          html.td([], [ui.tagsl(membership.tags)]),
          html.td([], [
            html.button(
              [
                event.on_click(EditMembership(membership)),
                attribute.class("btn small"),
              ],
              [html.text("edit")],
            ),
          ]),
        ])
      }),
    ),
  ])
}

fn view_membershp_modal(model: Model) {
  element.map(
    modal.view(model.modal, [
      html.div([attribute.class("")], [
        html.div([], [
          html.h1([attribute.class("font-bold text-xl mb-2")], [
            html.text("Edit Membership"),
          ]),
        ]),
        case model.membership {
          None -> html.div([], [])
          Some(membership) -> {
            let user = get_user(membership, model)

            html.form([event.on_submit(UpdateMembership)], [
              html.div([], [html.text(string.inspect(user))]),
              ui.select(
                "role",
                "Role",
                membership.role,
                [#("user", "user"), #("admin", "admin"), #("owner", "owner")],
                model.invitation_errors,
                fn(value) {
                  ChangeMembership(Membership(..membership, role: value))
                },
              ),
              ui.text(
                "tags",
                "Tags",
                tags.join2(membership.tags),
                model.invitation_errors,
                fn(value) {
                  ChangeMembership(
                    Membership(..membership, tags: tags.split(value)),
                  )
                },
              ),
              html.div([attribute.class("flex")], [
                html.div([], [view_remove_membership(membership, model)]),
                html.div([attribute.class("ml-auto")], [
                  html.button([attribute.class("btn-primary")], [
                    html.text("Update user membership"),
                  ]),
                ]),
              ]),
            ])
          }
        },
      ])
      |> element.map(modal.msg),
    ]),
    ModalMsg,
  )
}

fn view_remove_membership(membership: Membership, model: Model) {
  case model.confirming_remove {
    True -> {
      html.button(
        [
          event.on_click(RemoveMembership(membership)),
          attribute.type_("button"),
          attribute.class("btn-danger"),
        ],
        [html.text("Are you sure you want to delete this membership?")],
      )
    }

    False -> {
      html.button(
        [
          event.on_click(RemoveConfirm),
          attribute.type_("button"),
          attribute.class("btn"),
        ],
        [html.text("Delete Membership")],
      )
    }
  }
}

fn view_invite_modal(model: Model) {
  element.map(
    modal.view(model.modal_invite, [
      html.div([attribute.class("")], [
        html.div([], [
          html.h1([attribute.class("font-bold text-xl mb-2")], [
            html.text("Invite New Members"),
          ]),
        ]),
        html.form([event.on_submit(Invite)], [
          ui.text_autofocus(
            "email",
            "Email addresses",
            model.invitation.emails,
            model.invitation_errors,
            fn(value) {
              ChangeInvitation(Invitation(..model.invitation, emails: value))
            },
          ),
          ui.select(
            "role",
            "Role",
            model.invitation.role,
            [#("user", "user"), #("admin", "admin"), #("owner", "owner")],
            model.invitation_errors,
            fn(value) {
              ChangeInvitation(Invitation(..model.invitation, role: value))
            },
          ),
          ui.text(
            "tags",
            "Tags",
            model.invitation.tags,
            model.invitation_errors,
            fn(value) {
              ChangeInvitation(Invitation(..model.invitation, tags: value))
            },
          ),
          html.div([attribute.class("flex space-x-4 justify-end")], [
            html.button(
              [
                attribute.class("btn"),
                attribute.type_("button"),
                event.on_click(CancelInvite),
              ],
              [html.text("Cancel")],
            ),
            html.button([attribute.class("btn-primary")], [
              html.text("Invite new users"),
            ]),
          ]),
        ]),
      ])
      |> element.map(modal.msg),
    ]),
    ModalInviteMsg,
  )
}

fn get_user(membership: Membership, model: Model) {
  let result =
    model.payload.users
    |> list.find(fn(user) { user.id == membership.user_id })

  case result {
    Error(Nil) -> user.new()
    Ok(user) -> user
  }
}

pub fn subscriptions(_app: App, model: Model) -> Sub(Msg) {
  sub.batch([
    modal.subscriptions(model.modal)
      |> sub.map(ModalMsg),
    modal.subscriptions(model.modal_invite)
      |> sub.map(ModalInviteMsg),
  ])
}

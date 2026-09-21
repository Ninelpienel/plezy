/// Option names the free-form mpv config is not allowed to set.
///
/// Shared by the two places that enforce it: the config file Plezy writes for
/// libmpv ([MpvConfigFile.sanitize]) and the property path the platforms
/// without config-file support still use.
library;


/// Property names the free-form mpv config is not allowed to write.
///
/// Neither is an mpv property. The Linux plugin intercepts both by name and
/// moves its own persistent HDR state instead (linux/runner/mpv/mpv_plugin.cc),
/// and the custom config is applied *after* startup has pushed the stored
/// preferences, so a `hdr-enabled=yes` or `hdr-tone-mapping=player` line would
/// change the live plane without anything writing it back to [SettingsService].
/// The settings sheet renders its HDR switch and tone-mapping row straight off
/// those preferences with no native readback, so the UI would report one state
/// while the plane held another - for the whole session, and again after a
/// restart, since the next startup replays the same order rather than
/// reconciling.
///
/// Filtered rather than reordered: reordering would still leave the config as a
/// second writer of state the app owns, silently discarded on every startup
/// instead of silently winning. Nothing legitimate is lost - both names are
/// settings the player's own HDR controls already expose, and mean nothing to
/// mpv itself, so no platform is losing a real mpv property here.
const appInterceptedMpvProperties = {'hdr-enabled', 'hdr-tone-mapping'};

/// The above, plus the four real mpv properties the Linux video plane owns.
///
/// It writes all four as one unit and caches what it last applied so it can skip
/// a transaction that would change nothing. A config line writing one of them
/// moves mpv without moving that cache, and the next transaction then compares
/// against a value mpv no longer holds and skips the write it needed to make -
/// leaving mpv encoding one colour space while the surface is described as
/// another, the single state the two-phase apply exists to prevent.
///
/// Scoped to the plane deliberately. These are ordinary mpv properties
/// everywhere else, nothing caches them there, and no other platform exposes a
/// UI control for them - so withholding them off Linux would remove the user's
/// only way to set them and point the log at a control they do not have.
/// The windowed-VO family. Embedded video is pinned to vo=libmpv (the render
/// API the plane and every other embedded surface are created against); a
/// config line switching `vo` — or the `gpu-context`/`gpu-api` it rides on —
/// makes mpv re-create its output as a separate, uncontrollable window and
/// orphans the embedded render context. vo=gpu-next is windowed by
/// construction and compute shaders (ArtCNN) need it, so no embedded vo is
/// worth accepting; the skip log for these names says that instead of pointing
/// at the HDR settings.
const appEmbeddedOwnedMpvProperties = {'vo', 'gpu-context', 'gpu-api'};

const appOwnedMpvProperties = {
  ...appInterceptedMpvProperties,
  ...appEmbeddedOwnedMpvProperties,
  'target-trc',
  'target-prim',
  'target-peak',
  'tone-mapping',
};

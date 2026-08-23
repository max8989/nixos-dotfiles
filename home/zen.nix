# Zen Browser.
#
# Zen ships no auto-close (and, as of 1.20.2b, no auto-unload either — the
# `zen.tab-unloader.*` prefs the docs describe were removed upstream; the
# shipped pref list under `browser/omni.ja` has none of them). The only native
# lever is the manual "Clear" button in the sidebar
# (`zen.view.show-clear-tabs-button`, on by default).
#
# So tab expiry comes from an extension, force-installed via the Firefox
# enterprise-policy mechanism (Zen is Firefox 151 under the hood). Policies are
# baked into the wrapped package at
# `$out/lib/zen-bin-*/distribution/policies.json` — nothing is written into
# ~/.config/zen, so the existing profile keeps its tabs, history and logins.
#
# Deliberately no `profiles.<name>` block here: Home Manager only writes
# profiles.ini when `programs.zen-browser.profiles != {}`, and doing so would
# create a *new* profile dir alongside the live "Default Profile" one.
{ inputs, ... }:
{
  imports = [ inputs.zen-browser.homeModules.beta ];

  programs.zen-browser = {
    enable = true;

    policies = {
      ExtensionSettings = {
        # Tab Wrangler — closes tabs that have been inactive for N minutes and
        # parks them in a restorable "Tab Corral". Pinned tabs are never
        # closed, and Zen's Essentials are pinned tabs (they run through
        # ZenPinnedTabManager), so those survive.
        #
        # The key is the extension's gecko id from its manifest; the slug in
        # the URL is what AMO serves `latest.xpi` under.
        "{81b74d53-9416-4fb3-afa2-ab46684b253b}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/tabwrangler/latest.xpi";
          installation_mode = "force_installed";
        };
      };
    };

    # mozilla.cfg defaults — settable in about:config afterwards, unlike a
    # locked Preferences policy.
    #
    # Zen ships browser.tabs.unloadOnLowMemory = false (Firefox defaults it to
    # true). Turning it on lets tabs idle for longer than
    # browser.tabs.min_inactive_duration_before_unload (10 min, Zen's default)
    # be dropped from memory under pressure. That is RAM relief only — the tab
    # stays in the sidebar; Tab Wrangler is what actually removes it.
    extraPrefs = ''
      pref("browser.tabs.unloadOnLowMemory", true);
    '';
  };
}

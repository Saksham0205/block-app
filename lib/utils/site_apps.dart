import 'url_utils.dart';

/// Websites whose own app grabs their links. Blocking only the site would
/// leave the app wide open (tapping `x.com/home` opens the X app, not the
/// browser), so the editor offers to block both.
const _siteApps = <String, List<String>>{
  'x.com': ['com.twitter.android'],
  'twitter.com': ['com.twitter.android'],
  'youtube.com': ['com.google.android.youtube'],
  'youtu.be': ['com.google.android.youtube'],
  'instagram.com': ['com.instagram.android'],
  'facebook.com': ['com.facebook.katana', 'com.facebook.lite'],
  'fb.com': ['com.facebook.katana'],
  'reddit.com': ['com.reddit.frontpage'],
  'tiktok.com': ['com.zhiliaoapp.musically', 'com.ss.android.ugc.trill'],
  'snapchat.com': ['com.snapchat.android'],
  'netflix.com': ['com.netflix.mediaclient'],
  'linkedin.com': ['com.linkedin.android'],
  'pinterest.com': ['com.pinterest'],
  'twitch.tv': ['tv.twitch.android.app'],
  'discord.com': ['com.discord'],
  'telegram.org': ['org.telegram.messenger'],
  't.me': ['org.telegram.messenger'],
  'whatsapp.com': ['com.whatsapp'],
};

/// Package names of apps that own any of [domains].
Set<String> appsForDomains(Iterable<String> domains) {
  final result = <String>{};
  for (final domain in domains) {
    _siteApps.forEach((site, packages) {
      if (domainMatches(domain, site)) result.addAll(packages);
    });
  }
  return result;
}

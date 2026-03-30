package SciMinerUI;
# SciMiner 1.1 - Modern UI wrapper for CGI pages
# Provides topbar navigation and footer for all CGI-generated pages

use strict;
use warnings;
use Exporter 'import';
our @EXPORT_OK = qw(print_topbar print_footer print_head_extras);

sub print_head_extras {
    print qq{
<link rel="icon" type="image/svg+xml" href="/SciMiner1.1/favicon.svg">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
};
}

sub print_topbar {
    print qq{
<div style="background:linear-gradient(135deg,#00897b 0%,#004d40 100%);color:#fff;padding:0 24px;height:56px;display:flex;align-items:center;justify-content:space-between;position:sticky;top:0;z-index:100;box-shadow:0 1px 3px rgba(0,0,0,0.15);font-family:'Inter',-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <div style="display:flex;align-items:center;gap:10px;font-weight:700;font-size:18px;">
    <img src="/SciMiner1.1/favicon.svg" alt="SciMiner" style="width:28px;height:28px;border-radius:6px;">
    SciMiner <span style="font-size:11px;font-weight:400;opacity:0.7;margin-left:2px;">1.1</span>
  </div>
  <nav style="display:flex;align-items:center;gap:4px;">
    <a href="/SciMiner1.1/" style="color:rgba(255,255,255,0.85);font-size:13px;font-weight:500;padding:6px 12px;border-radius:6px;text-decoration:none;">Home</a>
    <a href="/SciMiner1.1/SciMiner/intro2.html" style="color:rgba(255,255,255,0.85);font-size:13px;font-weight:500;padding:6px 12px;border-radius:6px;text-decoration:none;">Introduction</a>
    <a href="/SciMiner1.1/cgi-bin/sciminerLaunch.cgi" style="color:rgba(255,255,255,0.85);font-size:13px;font-weight:500;padding:6px 12px;border-radius:6px;text-decoration:none;">Run SciMiner</a>
    <a href="/SciMiner1.1/cgi-bin/analysisLaunch.cgi" style="color:rgba(255,255,255,0.85);font-size:13px;font-weight:500;padding:6px 12px;border-radius:6px;text-decoration:none;">Analysis</a>
    <a href="/SciMiner1.1/cgi-bin/mergeQueriesLaunch.cgi" style="color:rgba(255,255,255,0.85);font-size:13px;font-weight:500;padding:6px 12px;border-radius:6px;text-decoration:none;">Merge Queries</a>
    <a href="/SciMiner1.1/cgi-bin/completedLaunch.cgi" style="color:rgba(255,255,255,0.85);font-size:13px;font-weight:500;padding:6px 12px;border-radius:6px;text-decoration:none;">Completed</a>
    <a href="/SciMiner1.1/SciMiner/download.html" style="color:rgba(255,255,255,0.85);font-size:13px;font-weight:500;padding:6px 12px;border-radius:6px;text-decoration:none;">Download</a>
    <a href="/SciMiner1.1/SciMiner/contact2.html" style="color:rgba(255,255,255,0.85);font-size:13px;font-weight:500;padding:6px 12px;border-radius:6px;text-decoration:none;">Contact</a>
  </nav>
</div>
<div style="max-width:960px;margin:0 auto;padding:24px 20px;">
};
}

sub print_footer {
    print qq{
</div><!-- end container -->
<footer style="background:#0f172a;color:#94a3b8;padding:20px 24px;font-size:13px;margin-top:40px;font-family:'Inter',-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <div style="max-width:960px;margin:0 auto;display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:12px;">
    <div><span style="color:#fff;font-weight:600;">SciMiner 1.1</span> &middot; <a href="/hurlab/" style="color:#5eead4;text-decoration:none;">Hur Lab</a>, University of North Dakota <span style="margin-left:8px;font-size:11px;opacity:0.6;">Last updated: 2026-03-26</span></div>
    <div style="display:flex;gap:16px;align-items:center;">
      <a href="/SciMiner/" style="color:#5eead4;text-decoration:none;">Classic</a>
      <span style="color:#fff;font-weight:600;">v1.1</span>
      <a href="/SciMiner2.0/" style="color:#5eead4;text-decoration:none;">v2.0</a>
    </div>
  </div>
</footer>
};
}

1;

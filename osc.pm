package osc;
use LWP::UserAgent ();
use Net::Netrc;
use XML::LibXML;
use Digest::MD5;

our ($apibase, $user, $password);
sub init() {
    $apibase=$ENV{OBSAPI}||'api.opensuse.org';
    my $mach = Net::Netrc->lookup($apibase) or die "no entry for $apibase found in ~/.netrc";
    ($user, $password) = $mach->lpa;
    die unless $user;
    die unless $password;
    our $UA = LWP::UserAgent->new(
        requests_redirectable=>[],
        parse_head=>0,
        timeout=>9,
        agent=>"bmwiedemann/perl-osc-0.01",
        keep_alive => 1);
}

# makeurl(['source', 'openSUSE:Factory', 'zstd'], {'rev'=> '2', 'expand'=> 1})
sub makeurl($;$)
{
    my($pathparts, $opts) = @_;
    $opts||={};
    my $p = "/".join("/", @$pathparts);
    if(keys(%$opts)) {
        $p.="?".join("&", map { "$_=$opts->{$_}" } sort keys %$opts);
    }
    return $p;
}

sub apireq($$)
{
    my ($method, $path) = @_;
    my $request = HTTP::Request->new($method, "https://$user:$password\@$apibase$path");
    my $response = $UA->request($request);
    if($response->code != 200) {die "need to handle code $response->code for $path ?"}
    return $response->content;
}

sub apiget($) {apireq('GET', shift)}

sub xmlget($) {
    my $xml = apireq('GET', shift);
    my $dom = XML::LibXML->load_xml(string => $xml);
    return $dom;
}

sub projectpkgs($) {
    my $project = shift;
    my $dom = xmlget(makeurl(['source', $project]));
    map {
        $_->to_literal();
    } $dom->findnodes('/directory/entry/@name');
}

sub projectpkginfos($) {
    my $project = shift;
    my @pkgs= projectpkgs($project);
    my $dom = xmlget(makeurl(['source', $project],{
        view=>"info", nofilename=>1,
        package=>join("&package=", @pkgs)}));
    my @srcinfos = $dom->findnodes('/sourceinfolist/sourceinfo');
    return @srcinfos;
}

sub projectcheckupdate() {
    my $project = `cat .osc/_project`;chomp($project);
    my @srcinfos = projectpkginfos($project);
    foreach my $srcinfo (@srcinfos) {
       my $pkg = $srcinfo->getAttribute("package");
       my $md5 = calcpkgmd5($pkg);
       if($md5 ne $srcinfo->getAttribute("verifymd5")) {
           print "needs update: $pkg\n";
       } else {
           print "is uptodate: $pkg\n";
       }
    }
}

sub calcpkgmd5($) {
    my $path = shift;
    my $dom = XML::LibXML->load_xml(location => $path."/.osc/_files");
    return Digest::MD5::md5_hex(
        join "", map {
            my $n = $_->{name};
            ($n eq "_link")?"":
            "$_->{md5}  $n\n"
        } $dom->findnodes('/directory/entry')
    );
}

1;

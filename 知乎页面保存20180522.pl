no warnings 'utf8';
use feature ':5.10';
use Mojo::UserAgent;
use Encode;
my $ua = Mojo::UserAgent->new;
$ua->transactor->name("Mozilla/5.0 (Windows NT 6.1) AppleWebKit/654.32 (KHTML, like Gecko) Chrome/60.0 Safari/654.32");
$ua->inactivity_timeout(30);
$ua->connect_timeout(30);
$ua->request_timeout(30);
$ua->max_connections(0);
$ua->max_redirects(7);
say "请输入知乎URL";
chomp( $url_o = <STDIN> );

if ( $url_o =~ m/question\/(\d+)/ ) {
    $id = $1;
}
$url_start = "https://www.zhihu.com/question/" . $id;
say "正在下载 " . $url_start;
$tx        = $ua->get($url_start);
$response  = $tx->result->body;
$page_utf8 = Encode::decode( 'utf8', $response );
$page_gbk  = Encode::encode( 'gbk', $page_utf8 );    #编码为系统默认编码，简体中文环境
if ( $page_gbk =~ m/<title[^<>]*>(.+?)<\/title>/s ) { $bookname = $1 }
$bookname =~ s/([^\x81-\xFE])\\/$1＼/g;
$bookname =~ s/([^\x81-\xFE])\|/$1｜/g;

#$bookname=~s/\\/＼/g;
$bookname =~ s/\//／/g;
$bookname =~ s/:/：/g;
$bookname =~ s/\*/＊/g;
$bookname =~ s/\?/？/g;
$bookname =~ s/</＜/g;
$bookname =~ s/>/＞/g;

#$bookname=~s/\|/｜/g;
say $bookname;
use FileHandle;
$fh = FileHandle->new(">$id.$bookname.htm");
binmode($fh);
if ( $response =~ m/(<h1 class="QuestionHeader-title".+?<\/h1>)/si ) {
    $title = $1;
}
if ( $response =~ m/data-state="([^"]+)"/si ) {
    $data_state = $1;
    use HTML::Entities;
    $data_state = decode_entities($data_state);
    if ( $data_state =~ /"editableDetail":"(.+?[^\\])"/ ) { $question = $1 }
    $question =~ s/\\(.)/$1/g;
}
$question =~ s/<button.+?<\/button>//;
if ( $response =~ m/<script src="([^"]+main\.app[^"]+)"/ ) {
    $url_js = $1;
}
$tx       = $ua->get($url_js);
$response = $tx->result->body;
if ( $response =~ m/(oauth [0-9a-zA-Z]+)/ ) {
    $authorization = $1;
}
say $fh '<html><head><meta charset="UTF-8">';
say $fh '<style type="text/css"><!--';
say $fh 'img{max-width:800px;}';
say $fh '//-->';
say $fh '</style>';
say $fh '</head><body>';
say $fh '<div style="max-width:700px;margin-left:auto;margin-right:auto;">';
say $fh $title;
say $fh '<a target="_blank" href="' . $url_start . '">' . $url_start . '</a><br>';
say $fh $question;
say $fh '<hr />';
my $url =
    "https://www.zhihu.com/api/v4/questions/"
  . $id
  . "/answers?include=data%5B*%5D.is_normal%2Cadmin_closed_comment%2Creward_info%2Cis_collapsed%2Cannotation_action%2Cannotation_detail%2Ccollapse_reason%2Cis_sticky%2Ccollapsed_by%2Csuggest_edit%2Ccomment_count%2Ccan_comment%2Ccontent%2Ceditable_content%2Cvoteup_count%2Creshipment_settings%2Ccomment_permission%2Ccreated_time%2Cupdated_time%2Creview_info%2Crelevant_info%2Cquestion%2Cexcerpt%2Crelationship.is_authorized%2Cis_author%2Cvoting%2Cis_thanked%2Cis_nothelp%2Cupvoted_followees%3Bdata%5B*%5D.mark_infos%5B*%5D.url%3Bdata%5B*%5D.author.follower_count%2Cbadge%5B%3F(type%3Dbest_answerer)%5D.topics&offset=0&limit=20&sort_by=default";
my $build_tx = $ua->build_tx( GET => $url );
$build_tx->req->headers->header( "authorization" => $authorization );
my $tx       = $ua->start($build_tx);
my $response = $tx->result->body;
use JSON;
my $perl_hash_or_arrayref = decode_json $response ;
$total_num = $perl_hash_or_arrayref->{'paging'}->{'totals'};

if ( $total_num / 20 > int( $total_num / 20 ) ) {
    $total_page = int( $total_num / 20 );
}
else {
    $total_page = int( $total_num / 20 ) - 1;
}
say "正在下载第 1 页，共 " . ( $total_page + 1 ) . " 页";
foreach my $i ( @{ $perl_hash_or_arrayref->{'data'} } ) {
    my $name       = $i->{'author'}->{'name'};
    my $pic_url    = $i->{'author'}->{'avatar_url'};
    my $author_url = "https://www.zhihu.com/people/" . $i->{'author'}->{'url_token'};
    say $fh '<br><img src="' . $pic_url . '">';
    say $fh '<a target="_blank" href="' . $author_url . '">' . $name . '</a><br>';
    my $content = $i->{'content'};
    $content =~ s/<\/noscript>|<noscript>//g;
    $content =~ s/src="data:image[^"]+"//g;
    $content =~ s/data-original="/src="/g;
    $content =~ s/<img[^<>]+src="[^<>]+hd\.jpg"[^<>]+>//g;
    $content =~ s/data-actual(src="[^"]+")/$1/g;
    say $fh $content;
    say $fh '<hr />';
}
foreach my $k ( 1 .. $total_page ) {
    my $page_offset = $k * 20;
    say "正在下载第 " . ( $k + 1 ) . " 页，共 " . ( $total_page + 1 ) . " 页";
    my $url =
        "https://www.zhihu.com/api/v4/questions/"
      . $id
      . "/answers?include=data%5B*%5D.is_normal%2Cadmin_closed_comment%2Creward_info%2Cis_collapsed%2Cannotation_action%2Cannotation_detail%2Ccollapse_reason%2Cis_sticky%2Ccollapsed_by%2Csuggest_edit%2Ccomment_count%2Ccan_comment%2Ccontent%2Ceditable_content%2Cvoteup_count%2Creshipment_settings%2Ccomment_permission%2Ccreated_time%2Cupdated_time%2Creview_info%2Crelevant_info%2Cquestion%2Cexcerpt%2Crelationship.is_authorized%2Cis_author%2Cvoting%2Cis_thanked%2Cis_nothelp%2Cupvoted_followees%3Bdata%5B*%5D.mark_infos%5B*%5D.url%3Bdata%5B*%5D.author.follower_count%2Cbadge%5B%3F(type%3Dbest_answerer)%5D.topics&offset="
      . $page_offset
      . "&limit=20&sort_by=default";
    my $build_tx = $ua->build_tx( GET => $url );
    $build_tx->req->headers->header( "authorization" => $authorization );
    my $tx       = $ua->start($build_tx);
    my $response = $tx->result->body;
    use JSON;
    my $perl_hash_or_arrayref = decode_json $response ;

    foreach my $i ( @{ $perl_hash_or_arrayref->{'data'} } ) {
        my $name       = $i->{'author'}->{'name'};
        my $pic_url    = $i->{'author'}->{'avatar_url'};
        my $author_url = "https://www.zhihu.com/people/" . $i->{'author'}->{'url_token'};
        say $fh '<br><img src="' . $pic_url . '">';
        say $fh '<a target="_blank" href="' . $author_url . '">' . $name . '</a><br>';
        my $content = $i->{'content'};
        $content =~ s/<\/noscript>|<noscript>//g;
        $content =~ s/src="data:image[^"]+"//g;
        $content =~ s/data-original="/src="/g;
        $content =~ s/<img[^<>]+src="[^<>]+hd\.jpg"[^<>]+>//g;
        $content =~ s/data-actual(src="[^"]+")/$1/g;
        say $fh $content;
        say $fh '<hr />';
    }
}
say $fh '</div>';
say $fh '</body></html>';
$fh->close;
system("pause");

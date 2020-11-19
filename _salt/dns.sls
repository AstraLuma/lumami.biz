#!pyobjects


def record(host, type, value):
    BotoRoute53.present(
        "%s_%s" % (host, type),
        name=host,
        value=value,
        zone="lumami.biz",
        record_type=type,
        ttl=(60*60),
    )


def alias(target, source, nameserver=None):
    ip4 = salt.dnsutil.A(source, nameserver=nameserver)
    if ip4:
        record(target, "A", ip4)

    ip6 = salt.dnsutil.AAAA(source, nameserver=nameserver)
    if ip6:
        record(target, "AAAA", ip6)

def getips(glob):
    ip4 = [
        ip
        for ips in salt.mine.get(glob, 'ipaddr.four').values()
        for ip in ips
    ]
    ip6 = [
        ip
        for ips in salt.mine.get(glob, 'ipaddr.six').values()
        for ip in ips
    ]
    return ip4, ip6

with BotoRoute53.hosted_zone_present(
    "lumami.biz.",
    domain_name="lumami.biz.",
    comment="",
):
    sh4, sh6 = getips('statichost-*')
    if sh4:
        record('lumami.biz', 'A', sh4)
        record('www.lumami.biz', 'A', sh4)
    if sh6:
        record('lumami.biz', 'AAAA', sh6)
        record('www.lumami.biz', 'AAAA', sh6)

    record("lumami.biz", "MX", [
        "10 in1-smtp.messagingengine.com.",
        "20 in2-smtp.messagingengine.com.",
    ])
    alias('mail.lumami.biz', 'mail.lumami.biz', nameserver='ns1.messagingengine.com')

    record("fm1._domainkey.lumami.biz", "CNAME", 'fm1.lumami.biz.dkim.fmhosted.com')
    record("fm2._domainkey.lumami.biz", "CNAME", 'fm2.lumami.biz.dkim.fmhosted.com')
    record("fm3._domainkey.lumami.biz", "CNAME", 'fm3.lumami.biz.dkim.fmhosted.com')

    record("lumami.biz", "TXT", [
        '"v=spf1 include:spf.messagingengine.com include:aspmx.googlemail.com ~all"',
        '"google-site-verification=8dC00FJrgWhuXtalc0Xhl_GsdcJDQeTY7IXaYnMaVRA"',
        '"keybase-site-verification=iI3RC_tb_cftVZYd9qHPFcWepn67Rrsc050CThfiya0"',
    ])

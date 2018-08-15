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


def alias(target, source):
    ip4 = salt.dnsutil.A(source)
    if ip4:
        record(target, "A", ip4)

    ip6 = salt.dnsutil.AAAA(source)
    if ip6:
        record(target, "AAAA", ip6)


with BotoRoute53.hosted_zone_present(
    "lumami.biz.",
    domain_name="lumami.biz.",
    comment="",
):
    record("lumami.biz", "MX", [
        "1 ASPMX.L.GOOGLE.COM.",
        "5 ALT1.ASPMX.L.GOOGLE.COM.",
        "5 ALT2.ASPMX.L.GOOGLE.COM.",
        "10 ASPMX2.GOOGLEMAIL.COM.",
        "10 ASPMX3.GOOGLEMAIL.COM.",
    ])

    record("lumami.biz", "TXT", [
        '"v=spf1 include:aspmx.googlemail.com ~all"',
        '"google-site-verification=8dC00FJrgWhuXtalc0Xhl_GsdcJDQeTY7IXaYnMaVRA"',
    ])
import React from 'react'

import Link from '@docusaurus/Link';
import useBaseUrl from '@docusaurus/useBaseUrl';

const Divider = () => (
    <span className='in-blog-cta--divider'> → </span>
)

const InBlogCta = () => (
    <p>
        <Link className='in-blog-cta--link' to={useBaseUrl('/docs')}>
            We are in Alpha (try it out)!
        </Link>
        <Divider />
        <Link className='in-blog-cta--link' to='https://discord.gg/rzdnErX'>
            Join our community
        </Link>
        <Divider />
        <Link className='in-blog-cta--link'
            to='https://wasp-lang.notion.site/Founding-Engineer-at-Wasp-402274568afa4d7eb7f428f8fa2c0816'>
            Work with us
        </Link>
    </p>
)

export default InBlogCta

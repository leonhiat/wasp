import config from '../../config.js'

export const googleSignInUrl = `${config.apiUrl}/auth/external/google/login`

// Note: Using `style` instead of `height` to work with Tailwind,
// which sets `height: auto` for `img`.
export function GoogleSignInButton(props) {
  return (
    <a href={googleSignInUrl}>
      <img alt="Sign in with Google"
        style={{ height: props.height || 40 }}
        src="/images/btn_google_signin_dark_normal_web@2x.png" />
    </a>
  )
}

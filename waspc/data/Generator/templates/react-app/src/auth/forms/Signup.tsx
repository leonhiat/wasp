import Auth from './Auth'
import { type CustomizationOptions, State } from './types'

export function SignupForm({
  appearance,
  logo,
  socialLayout,
}: CustomizationOptions) {
  return (
    <Auth
      appearance={appearance}
      logo={logo}
      socialLayout={socialLayout}
      state={State.Signup}
    />
  )
}

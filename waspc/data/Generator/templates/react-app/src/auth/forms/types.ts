{{={= =}=}}
import { createTheme } from '@stitches/react'

export enum State {
  Login = 'login',
  Signup = 'signup',
  {=# isEmailAuthEnabled =}
  ForgotPassword = 'forgot-password',
  ResetPassword = 'reset-password',
  VerifyEmail = 'verify-email',
  {=/ isEmailAuthEnabled =}
}

export type CustomizationOptions = {
  logo?: string
  socialLayout?: 'horizontal' | 'vertical'
  appearance?: Parameters<typeof createTheme>[0]
}

export type ErrorMessage = {
  title: string
  description?: string
}

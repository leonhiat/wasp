import { createDefineAdditionalSignupFieldsFn } from '../types.js'

export type GetVerificationEmailContentFn = (params: { verificationLink: string }) => EmailContent;

export type GetPasswordResetEmailContentFn = (params: { passwordResetLink: string }) => EmailContent;

type EmailContent = {
    subject: string;
    html: string;
    text: string;
}

export const tokenVerificationErrors = {
    TokenExpiredError: 'TokenExpiredError',
};

export const defineAdditionalSignupFields = createDefineAdditionalSignupFieldsFn<"email" | "password">()

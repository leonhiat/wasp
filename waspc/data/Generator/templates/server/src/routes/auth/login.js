{{={= =}=}}
import Prisma from '@prisma/client'
import SecurePassword from 'secure-password'

import { sign, verifyPassword } from '../../core/auth.js'
import { handleRejection } from '../../utils.js'

const prisma = new Prisma.PrismaClient()

export default handleRejection(async (req, res) => {
  const args = req.body || {}
  const context = {}

  // Try to fetch user with the given email.
  const {= userEntityLower =} = await prisma.{= userEntityLower =}.findOne({ where: { email: args.email.toLowerCase() } })
  if (!user) {
    return res.status(401).send()
  }

  // We got user - now check the password.
  const verifyPassRes = await verifyPassword({= userEntityLower =}.password, args.password)
  switch (verifyPassRes) {
    case SecurePassword.VALID:
      break
    case SecurePassword.VALID_NEEDS_REHASH:
      // TODO(matija): take neccessary steps to make the password more secure.
      break
    default:
      return res.status(401).send()
  }

  // Email & password valid - generate token.
  const token = await sign({= userEntityLower =}.id)

  // NOTE(matija): Possible option - instead of explicitly returning token here,
  // we could add to response header 'Set-Cookie {token}' directive which would then make
  // browser automatically save cookie with token.

  return res.json({ token })
})


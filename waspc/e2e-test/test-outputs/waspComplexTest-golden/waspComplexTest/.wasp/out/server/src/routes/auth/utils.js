
import { v4 as uuidv4 } from 'uuid'

import prisma from '../../dbClient.js'

export const contextWithUserEntity = {
  entities: {
    User: prisma.user
  }
}

export const authConfig = {
  failureRedirectPath: "/login",
  successRedirectPath: "/",
}

export async function findOrCreateUserByExternalAuthAssociation(provider, providerId, getUserFields) {
  // Attempt to find a User by an external auth association.
  const externalAuthAssociation = await prisma.socialLogin.findFirst({
    where: { provider, providerId },
    include: { user: true }
  })

  if (externalAuthAssociation) {
    return externalAuthAssociation.user
  }

  // No external auth association linkage found. Create a new User using details from
  // `getUserFields()`. Additionally, associate the externalAuthAssociations with the new User.
  // NOTE: For now, we force a random (uuidv4) password string. In the future, we will allow password reset.
  const userFields = await getUserFields()
  const userAndExternalAuthAssociation = {
    ...userFields,
    password: uuidv4(),
    externalAuthAssociations: {
      create: [{ provider, providerId }]
    }
  }

  return await prisma.user.create({ data: userAndExternalAuthAssociation })
}

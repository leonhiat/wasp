{{={= =}=}}
import prisma from '../dbClient.js'

{=& jsFnImportStatement =}

{=! TODO: This template is exactly the same at the moment as one for queries,
          consider in the future if it is worth removing this duplication. =}

export default async function (args, context) {
  return {= jsFnIdentifier =}(args, {
    ...context,
    entities: {
      {=# entities =}
      {= name =}: prisma.{= prismaIdentifier =},
      {=/ entities =}
    },
  })
}

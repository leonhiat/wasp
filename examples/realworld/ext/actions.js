import { createNewUser } from '@wasp/core/auth.js'
import HttpError from '@wasp/core/HttpError.js'

export const signup = async ({ username, email, password }, context) => {
  try {
    await createNewUser({ username, email, password })
  } catch (err) {
    // TODO: I wish I didn't have to do this, I would love this to be in some
    //   degree done automatically.
    if (err.code == 'P2002') {
      throw new HttpError(400, err.meta.target + " must be unique.")
    }
    throw err
  }
}

export const updateUser = async ({ email, username, bio, profilePictureUrl, newPassword }, context) => {
  if (!context.user) { throw new HttpError(403) }

  // TODO: Nicer error handling! Right now everything is returned as 500 while it could be instead
  //   useful error message about username being taken / not unique, and other validation errors.
  await context.entities.User.update({
    where: { id: context.user.id },
    data: {
      email,
      username,
      bio,
      profilePictureUrl,
      password: newPassword || undefined
    }
  })
}

export const createArticle = async ({ title, description, markdownContent }, context) => {
  if (!context.user) { throw new HttpError(403) }

  // TODO: Nicer error handling! Right now everything is returned as 500 while it could be instead
  //   useful error message about username being taken / not unique, and other validation errors.
  return await context.entities.Article.create({
    data: {
      title,
      description,
      markdownContent,
      user: { connect: { id: context.user.id } }
    }
  })
}

export const updateArticle = async ({ id, title, description, markdownContent }, context) => {
  if (!context.user) { throw new HttpError(403) }

  // TODO: Nicer error handling! Right now everything is returned as 500 while it could be instead
  //   useful error message about username being taken / not unique, and other validation errors.
  await context.entities.Article.updateMany({
    where: { id, user: { id: context.user.id }}, // TODO: This line is not fun to write.
    data: {
      title,
      description,
      markdownContent
    }
  })
}

export const deleteArticle = async ({ id }, context) => {
  if (!context.user) { throw new HttpError(403) }

  // TODO: Nicer error handling! Right now everything is returned as 500 while it could be instead
  //   useful error message about username being taken / not unique, and other validation errors.
  await context.entities.Article.deleteMany({
    where: { id, user: { id: context.user.id }} // TODO: This line is not fun to write.
  })
}

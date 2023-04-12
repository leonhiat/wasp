import Prisma from '@prisma/client'
import HttpError from './core/HttpError.js'

import { readdir } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from 'url';

/**
 * Decorator for async express middleware that handles promise rejections.
 * @param {Func} middleware - Express middleware function.
 * @returns {Func} Express middleware that is exactly the same as the given middleware but,
 *   if given middleware returns promise, reject of that promise will be correctly handled,
 *   meaning that error will be forwarded to next().
 */
export const handleRejection = (middleware) => async (req, res, next) => {
  try {
    await middleware(req, res, next)
  } catch (error) {
    next(error)
  }
}

export const isPrismaError = (e) => {
  return e instanceof Prisma.PrismaClientKnownRequestError ||
    e instanceof Prisma.PrismaClientUnknownRequestError ||
    e instanceof Prisma.PrismaClientRustPanicError ||
    e instanceof Prisma.PrismaClientInitializationError ||
    e instanceof Prisma.PrismaClientValidationError
}

export const prismaErrorToHttpError = (e) => {
  if (e instanceof Prisma.PrismaClientKnownRequestError) {
    if (e.code === 'P2002') {
      return new HttpError(422, 'Save failed', {
        message: `user with the same ${e.meta.target.join(', ')} already exists`,
        target: e.meta.target
      })
    } else {
      // TODO(shayne): Go through https://www.prisma.io/docs/reference/api-reference/error-reference#error-codes
      // and decide which are input errors (422) and which are not (500)
      // See: https://github.com/wasp-lang/wasp/issues/384
      return new HttpError(500)
    }
  } else if (e instanceof Prisma.PrismaClientValidationError) {
    return new HttpError(422, 'Save failed')
  } else {
    return new HttpError(500)
  }
}

export const sleep = ms => new Promise(r => setTimeout(r, ms))

export function getDirFromFileUrl(fileUrl) {
  return fileURLToPath(dirname(fileUrl));
}

export async function importJsFilesFromDir(absoluteDir, relativePath, whitelist = null) {
  const pathToDir = join(absoluteDir, relativePath);

  return new Promise((resolve, reject) => {
    readdir(pathToDir, async (err, files) => {
      if (err) {
        return reject(err);
      }
      const importPromises = files
        .filter((file) => file.endsWith(".js") && isWhitelisted(file))
        .map((file) => import(`${pathToDir}/${file}`));
      resolve(Promise.all(importPromises));
    });
  });

  function isWhitelisted(file) {
    // No whitelist means all files are whitelisted
    if (!Array.isArray(whitelist)) {
      return true;
    }
    return whitelist.some((whitelistedFile) => file.endsWith(whitelistedFile));
  }
}

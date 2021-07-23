---
title: "Creating tasks"
---

import useBaseUrl from '@docusaurus/useBaseUrl';

To enable creation of new tasks, we will need two things:
1. Wasp action that creates a new task.
2. React form that calls that action with the new task's data.

## Action
Creating an action is very similar to creating a query.

### Wasp declaration

First we declare the action in Wasp:
```c title="main.wasp"
// ...

action createTask {
  fn: import { createTask } from "@ext/actions.js",
  entities: [Task]
}
```

### JS implementation

Next, we define a JS function for that action:
```js title="ext/actions.js"
export const createTask = async (args, context) => {
  return context.entities.Task.create({
    data: { description: args.description }
  })
}
```

:::tip
We put JS function in new file `ext/actions.js`, but we could have put it anywhere we wanted, there are no limitations here, as long as the import statement in Wasp file is correct and it is inside `ext/` dir.
:::

## React form

```jsx {5,12,39-61} title="ext/MainPage.js"
import React from 'react'

import { useQuery } from '@wasp/queries'
import getTasks from '@wasp/queries/getTasks'
import createTask from '@wasp/actions/createTask'

const MainPage = () => {
  const { data: tasks, isFetching, error } = useQuery(getTasks)

  return (
    <div>
      <NewTaskForm />

      {tasks && <TasksList tasks={tasks} />}

      {isFetching && 'Fetching...'}
      {error && 'Error: ' + error}
    </div>
  )
}

const Task = (props) => {
  return (
    <div>
      <input
        type='checkbox' id={props.task.id}
        checked={props.task.isDone} readonly
      />
      {props.task.description}
    </div>
  )
}

const TasksList = (props) => {
  if (!props.tasks?.length) return 'No tasks'
  return props.tasks.map((task, idx) => <Task task={task} key={idx} />)
}

const NewTaskForm = (props) => {
  const handleSubmit = async (event) => {
    event.preventDefault()
    try {
      const description = event.target.description.value
      event.target.reset()
      await createTask({ description })
    } catch (err) {
      window.alert('Error: ' + err.message)
    }
  }

  return (
    <form onSubmit={handleSubmit}>
      <input
        name='description'
        type='text'
        defaultValue=''
      />
      <input type='submit' value='Create task' />
    </form>
  )
}

export default MainPage
```

Here we call our action directly (no hooks) because we don't need any reactivity. The rest is just regular React code.

That's it! 
Try creating a "Build a Todo App in Wasp" task and see it appear in the list below.
Task is created on the server and also saved in the database. Try refreshing the page or opening it in another browser - you'll see the tasks are still here!

<img alt="Todo App - creating new task"
     src={useBaseUrl('img/todo-app-new-task.png')}
     style={{ border: "1px solid black" }}
/>

## Side note: Automatic invalidation/updating of queries
You will notice that when you create a new task, the list of tasks is automatically updated with that new task, although we have written no code to take care of that! Normally, you would have to do this explicitly, e.g. with react-query you would invalidate the `getTasks` query via its key, or would call its `refetch()` method.

The reason why `getTasks` query automatically updates when `createTask` action is executed is because Wasp is aware that both of them are working with `Task` entity, and therefore assumes that action that operates on `Task` (in this case `createTask`) might have changed the result of `getTasks` query. Therefore, in the background, Wasp nudges `getTasks` query to update. This means that **out of the box, Wasp will make sure that all your queries that deal with entities are always in sync with any changes that the actions might have done**.

:::note
While this kind of approach to automatic invalidation of queries is very convenient, it is in some situations wasteful and could become a performance bottleneck as an app grows. In that case, you will be able to override this default behaviour and instead provide more detailed (and performant) instructions on how the specific action should affect queries. This is not yet implemented, but is something we plan to do and you can track the progress [here](https://github.com/wasp-lang/wasp/issues/63) (or even contribute!).
:::

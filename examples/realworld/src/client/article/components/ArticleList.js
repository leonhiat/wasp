import React from 'react'
import { Link } from 'react-router-dom'
import moment from 'moment'

import Button from '@material-ui/core/Button'
import Card from '@material-ui/core/Card'
import CardContent from '@material-ui/core/CardContent'
import CardActions from '@material-ui/core/CardActions'
import CardHeader from '@material-ui/core/CardHeader'
import Avatar from '@material-ui/core/Avatar'
import Typography from '@material-ui/core/Typography'
import { makeStyles } from '@material-ui/core/styles'
import Chip from '@material-ui/core/Chip'

import setArticleFavorited from '@wasp/actions/setArticleFavorited'

const useStyles = makeStyles((theme) => ({
  root: {
  },
  article: {
    marginBottom: theme.spacing(1)
  },
  tags: {
    marginLeft: 'auto'
  },
  chip: {
    margin: theme.spacing(0.5),
  },
}));


const ArticleList = (props) => {
  const articles = props.articles

  return articles ? (
    <div>
      { articles.map(article => <Article article={article} key={article.id} />) }
    </div>
  ) : null
}

const Article = (props) => {
  const classes = useStyles()
  const article = props.article

  const toggleArticleFavorited = async () => {
    await setArticleFavorited({ id: article.id, favorited: !article.favorited })
  }

  return (
    <Card className={classes.article} elevation={2}>
      <CardHeader
        avatar={<Avatar>A</Avatar>}
        title={article.user.username}
        subheader={moment(article.createdAt).format('MMMM DD, YYYY')}
      />

      <CardContent>
        <Typography variant="h5">
          <Link to={`/article/${article.slug}`}>
            { article.title }
          </Link>
        </Typography>
        <Typography variant="body2" color="textSecondary" component="p">
          { article.description }
        </Typography>


      </CardContent>
      <CardActions disableSpacing>
        <Button onClick={toggleArticleFavorited} size="small" color="primary">
          { article.favorited ? 'Unlike' : 'Like' } ({ article.favoritesCount })
        </Button>

        <Button component={ Link } to={`/article/${article.slug}`} size="small" color="primary">
          Read more
        </Button>
        <span className={classes.tags}>
          { article.tags.map(tag => (
            <Chip key={tag.name} className={classes.chip} label={tag.name}/>
          ))}
        </span>
      </CardActions>

    </Card>
  )
}

export default ArticleList

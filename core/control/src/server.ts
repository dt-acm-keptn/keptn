import * as bodyParser from 'body-parser';
import * as express from 'express';
import 'reflect-metadata';
import { Container } from 'inversify';
import {
  interfaces,
  InversifyExpressServer,
  TYPE,
} from 'inversify-express-utils';
import * as swagger from 'swagger-express-ts';

// import controllers
import './config/ConfigController';
import './auth/AuthController';
import './project/ProjectController';
import './service/ServiceController';

// import models
import './config/ConfigRequestModel';
import './auth/AuthRequestModel';
import './project/ProjectRequestModel';
import './service/ServiceRequestModel';

// tslint:disable-next-line: import-name
import RequestLogger = require('./middleware/requestLogger');
import authenticator = require('./middleware/authenticator');
import * as path from 'path';
import { MessageService } from './svc/MessageService';

const port: number = Number(process.env.PORT) || 5001; // or from a configuration file
const swaggerUiAssetPath = require('swagger-ui-dist').getAbsoluteFSPath();
// import models

// set up container
const container = new Container();

// set up bindings
container.bind<MessageService>('MessageService').to(MessageService);

// create server
const server = new InversifyExpressServer(container);

server.setConfig((app: any) => {
  app.use('/api-docs/swagger', express.static(path.join(__dirname, '/src/swagger')));
  app.use('/api-docs/swagger/assets',
          express.static(
            swaggerUiAssetPath,
          ),
    );
  app.use(bodyParser.json());
  app.use(RequestLogger);
  app.use(
    swagger.express({
      definition: {
        info: {
          title: 'Keptn Control API',
          version: '0.2',
        },
        externalDocs: {
          url: '',
        },
        // Models can be defined here
      },
    }),
  );
  if (process.env.NODE_ENV === 'production') {
    app.use(authenticator);
  }
});

server.setErrorConfig((app: any) => {
  app.use(
    (
      err: Error,
      request: express.Request,
      response: express.Response,
      next: express.NextFunction,
    ) => {
      console.error(err.stack);
      response.status(500).send('Something broke!');
    },
  );
});

const app = server.build();
app.listen(port);
console.info(`Server is listening on port : ${port}`);

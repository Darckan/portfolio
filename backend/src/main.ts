import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { existsSync } from 'fs';
import * as dotenv from 'dotenv';

async function bootstrap(): Promise<void> {
  if (!process.env.IS_DOCKER && existsSync('.env')) {
    dotenv.config({ path: '.env' });
  }

  const app = await NestFactory.create(AppModule);
  await app.listen(process.env.PORT ?? 3000);
}
bootstrap();

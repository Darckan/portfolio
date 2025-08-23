import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TestModule } from './test/test.module';
import { PrometheusModule } from '@willsoto/nestjs-prometheus';

@Module({
  imports: [
    TypeOrmModule.forRoot({
      type: 'mysql',
      host: process.env.DB_HOST ?? 'mysql',
      port: 3306,
      username: process.env.DB_USER ?? 'root',
      password: process.env.DB_PASSWORD ?? 'password',
      database: process.env.DB_NAME ?? 'test',
      autoLoadEntities: true,
      synchronize: true,
    }),
    TestModule,
    PrometheusModule.register(),
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}

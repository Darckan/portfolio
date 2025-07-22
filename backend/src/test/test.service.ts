import { Injectable } from '@nestjs/common';

@Injectable()
export class TestService {
  async findAll(): Promise<{ message: string; status: 'ok' | 'error' }> {
    return {
      message: '✅ Conexión OK desde NestJS a la DB test',
      status: 'ok',
    };
  }
}
